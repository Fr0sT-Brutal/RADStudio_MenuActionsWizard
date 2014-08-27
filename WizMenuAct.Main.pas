//* MenuActions expert/wizard for RAD studio *\\
//*               Main unit                  *\\
//*                © Fr0sT                   *\\

unit WizMenuAct.Main;

interface

uses Windows, Classes, Menus, SysUtils, ComCtrls, Registry, Controls,
     ToolsApi, Graphics, ExtCtrls, Forms, Vcl.ActnList, Types, StrUtils,
     WizMenuAct.BaseWiz;

type
  TActionInfo = record
    Action: TCustomAction;
    Name, Caption: string;
    DefShortcut: TShortCut;
    CustShortcut: TShortCut;  // if absent, = DefShortcut
    function ShortcutModified: Boolean;
  end;
  PActionInfo = ^TActionInfo;

  TWizard = class(TBaseWizard, INTAAddInOptions)
  private
    FActions: TList;
    FEnvOpts: INTAEnvironmentOptionsServices;
    FOptsFrame: TCustomFrame;
    function FindByName(ActName: string): PActionInfo;
  public
    constructor Create;
    destructor Destroy; override;

    function CheckReady: Boolean; override;
    procedure Startup; override;
    procedure Cleanup; override;

    // *** Option page's frame methods ***

    { Indicates where this option page should appear in the treeview in the
      Tools | Options dialog.  If this function returns an empty string, this
      page will appear under the Third Party area.  It is strongly suggested
      that you return an empty string from this function. }
    function GetArea: string;
    { Indicates the name of the node that should appear in the treeview in the
      Tools | Options dialog.  This node will appear under the node specified by
      "GetArea". }
    function GetCaption: string;
    { Returns the class of the frame that you want embedded in this options page }
    function GetFrameClass: TCustomFrameClass;
    { Called when the instance of the specified frame class is created }
    procedure FrameCreated(AFrame: TCustomFrame);
    { Called when the user closes the Options dialog that contains this page.
      The "Accepted" parameter is True if the user clicked OK, or False if the
      user clicked Cancel }
    procedure DialogClosed(Accepted: Boolean);
    { Called before the dialog is closed. Allows you to validate the input on
      your option page.  If there is invalid input, you should display an error
      message and return False.  Return True if there are no errors }
    function ValidateContents: Boolean;
    { Return the Help Context for this options page }
    function GetHelpContext: Integer;
    { Indicates whether or not this page will be automatically included in IDE
      Insight.  If True, it will be included in the "Preferences" node like all
      built-in pages from the Tools | Options dialog.  It is recommended that
      you return True. }
    function IncludeInIDEInsight: Boolean;

    procedure ApplyShortcuts;
    procedure ReadSettings;
    procedure SaveSettings;
  end;

implementation

uses WizMenuAct.FormSettings;

resourcestring
  SWizardEntry = 'Edit action shortcuts';

const // not localizable
  SWizardName = 'MenuActionsWizard';
  SWizardID = 'Fr0sT.MenuActionsWizard';
  SRegCustShortcutsName = 'CustomShortcuts';
  SRegColWidName = 'ColWidth';

function CreateInstFunc: TBaseWizard;
begin
  Result := TWizard.Create;
end;

// registry iterator function

type
  TRegValuesForEachFn = reference to procedure(const ValName: string);

procedure RegValuesForEach(Reg: TRegistry; Callback: TRegValuesForEachFn);
var
  Len: DWORD;
  I: Integer;
  Info: TRegKeyInfo;
  S: string;
begin
  if Reg.GetKeyInfo(Info) then
  begin
    SetString(S, nil, Info.MaxValueLen + 1);
    for I := Info.NumValues - 1 downto 0 do
    begin
      Len := Info.MaxValueLen + 1;
      RegEnumValue(Reg.CurrentKey, I, PChar(S), Len, nil, nil, nil, nil);
      Callback(PChar(S));
    end;
  end;
end;

type
  TStrArray = TArray<string>;

function Split(const Str: string; Delim: string; AllowEmpty: Boolean): TStrArray;
var CurrDelim, NextDelim, CurrIdx: Integer;
begin
  if Str = '' then begin SetLength(Result, 0); Exit; end;
  CurrDelim := 1; CurrIdx := 0; SetLength(Result, 16);
  repeat
    if CurrIdx = Length(Result) then
      SetLength(Result, CurrIdx + 16);
    NextDelim := PosEx(Delim, Str, CurrDelim);
    if NextDelim = 0 then NextDelim := Length(Str)+1;
    Result[CurrIdx] := Copy(Str, CurrDelim, NextDelim - CurrDelim);
    CurrDelim := NextDelim + Length(Delim);
    if (Result[CurrIdx] <> '') or AllowEmpty
      then Inc(CurrIdx)
      else Continue;
  until CurrDelim > Length(Str);
  SetLength(Result, CurrIdx);
end;

function Join(const Arr: array of string; Delim: string; AllowEmpty: Boolean): string;
var
  i: Integer;
  WasAdded: Boolean;
begin
  Result := ''; WasAdded := False;
  for i := Low(Arr) to High(Arr) do
  begin
    if (Arr[i] = '') and not AllowEmpty then Continue;
    if not WasAdded
      then Result := Arr[i]
      else Result := Result + Delim + Arr[i];
    WasAdded := True;
  end;
end;

{ TActionInfo }

function TActionInfo.ShortcutModified: Boolean;
begin
  Result := DefShortcut <> CustShortcut;
end;

{$REGION 'TWizard'}

constructor TWizard.Create;
begin
  inherited Create([optUseConfig, optUseDelayed]);

  FActions := TList.Create;

  // interface is used for registering Options page
  if not (
    Supports(BorlandIDEServices, INTAEnvironmentOptionsServices, FEnvOpts)
  ) then raise Exception.Create(SMsgUnsupportedIDE);

  // we'll read options later, on Startup
end;

function TWizard.CheckReady: Boolean;
begin
  Result := INSrv.ActionList <> nil;
end;

procedure TWizard.Startup;
var
  act: TContainedAction;
  pActInf: PActionInfo;
begin
log('TWizard.Startup');
  // fill actions list
  for act in INSrv.ActionList do
  begin
    if not (act is TCustomAction) then Continue; // shortcuts not supported
    if act.Name = '' then Continue;              // we identify actions by name, so empty names will confuse us
    New(pActInf);
    pActInf.Action := TCustomAction(act);
    pActInf.Name := act.Name;
    pActInf.Caption := TCustomAction(act).Caption;
    pActInf.DefShortcut := TCustomAction(act).ShortCut;
    pActInf.CustShortcut := TCustomAction(act).ShortCut;
    FActions.Add(pActInf);
  end;

  // index by Name
  FActions.SortList(
    function(item1, item2: Pointer): Integer
    begin
      if PActionInfo(item1).Name < PActionInfo(item2).Name then
        Result := LessThanValue
      else if PActionInfo(item1).Name > PActionInfo(item2).Name then
        Result := GreaterThanValue
      else
        Result := EqualsValue;
    end);

  ReadSettings;
  ApplyShortcuts;
  // add our custom Options page
  FEnvOpts.RegisterAddInOptions(Self);
end;

procedure TWizard.Cleanup;
var i: Integer;
begin
log('TWizard.Cleanup');
  SaveSettings;
  for i := 0 to FActions.Count - 1 do
    FreeMem(PActionInfo(FActions[i]));
  FActions.Clear;
end;

// Change shortcuts of actions
procedure TWizard.ApplyShortcuts;
var
  pActInf: PActionInfo;
begin
  for pActInf in FActions do
    if pActInf.Action.ShortCut <> pActInf.CustShortcut then
      pActInf.Action.ShortCut := pActInf.CustShortcut;
end;

// Shortcuts are stored inside the key %WizKey%\CustomShortcuts in the form
//   %Action name%=%def shortcut%;%custom shortcut%
// %def shortcut% is saved in order to keep custom shortcuts between wizard
// runs (wizard modifies an action's shortcut - unloads - loads - and then
// considers modified shortcut as default thus removing custom shortcut key).

procedure TWizard.ReadSettings;
var
  pActInf: PActionInfo;
  s: string;
  i: Integer;
begin
  // read custom shortcuts
  // We save the current registry path to be able to return there. Unluckily registry
  // has no "go up" action.
  s := ConfigKey.CurrentPath;
  ConfigKey.OpenKey(SRegCustShortcutsName, True);
  RegValuesForEach(ConfigKey,
    procedure(const ValName: string)
    var shortcuts: TStrArray;
    begin
      pActInf := FindByName(ValName);
      // read default and custom shortcut, assign them
      if pActInf = nil then Exit;
      shortcuts := Split(ConfigKey.ReadString(ValName), ';', True);
      pActInf.DefShortcut  := TShortCut(StrToInt(shortcuts[0]));
      pActInf.CustShortcut := TShortCut(StrToInt(shortcuts[1]));
    end);
  // go back to the base key. We have to jump to the root first
  ConfigKey.OpenKey('\', False);
  ConfigKey.OpenKey(s, True);

  // read other options
  for i := Low(FrameOptions.ColWidths) to High(FrameOptions.ColWidths) do
  begin
    s := SRegColWidName+IntToStr(i);
    if ConfigKey.ValueExists(s) then
      FrameOptions.ColWidths[i] := ConfigKey.ReadInteger(s);
  end;
end;

procedure TWizard.SaveSettings;
var
  pActInf: PActionInfo;
  i: Integer;
  s: string;
begin
  // re-fill custom shortcuts
  ConfigKey.DeleteKey(SRegCustShortcutsName);
  // We save the current registry path to be able to return there. Unluckily registry
  // has no "go up" action.
  s := ConfigKey.CurrentPath;
  ConfigKey.OpenKey(SRegCustShortcutsName, True);
  for pActInf in FActions do
    if pActInf.ShortcutModified then
      ConfigKey.WriteString(pActInf.Name, Join([IntToStr(pActInf.DefShortcut), IntToStr(pActInf.CustShortcut)], ';', True));
  // go back to the base key. We have to jump to the root first
  ConfigKey.OpenKey('\', False);
  ConfigKey.OpenKey(s, True);

  // write other options
  for i := Low(FrameOptions.ColWidths) to High(FrameOptions.ColWidths) do
    if FrameOptions.ColWidths[i] <> 0 then
      ConfigKey.WriteInteger(SRegColWidName+IntToStr(i), FrameOptions.ColWidths[i]);
end;

// helper function to locate by name
function TWizard.FindByName(ActName: string): PActionInfo;
var
  idx: Integer;
begin
  for idx := 0 to FActions.Count - 1 do
    if PActionInfo(FActions[idx]).Name = ActName
      then Exit(FActions[idx]);
  Result := nil;
end;

// *** Option page's frame methods ***

procedure TWizard.FrameCreated(AFrame: TCustomFrame);
begin
  FOptsFrame := AFrame;
  TfrmSettings(FOptsFrame).Init(FActions);
end;

destructor TWizard.Destroy;
begin
  FreeAndNil(FActions);
  inherited;
end;

procedure TWizard.DialogClosed(Accepted: Boolean);
begin
  TfrmSettings(FOptsFrame).Close(Accepted);
  FOptsFrame := nil;
  if Accepted then
  begin
    SaveSettings;
    ApplyShortcuts;
  end;
end;

function TWizard.GetArea: string;
begin
  Result := '';
end;

function TWizard.GetCaption: string;
begin
  Result := SWizardEntry;
end;

function TWizard.GetFrameClass: TCustomFrameClass;
begin
  Result := TfrmSettings;
end;

function TWizard.GetHelpContext: Integer;
begin
  Result := -1;
end;

function TWizard.IncludeInIDEInsight: Boolean;
begin
  Result := True;
end;

function TWizard.ValidateContents: Boolean;
begin
  Result := True;
end;

{$ENDREGION}

initialization
  WizMenuAct.BaseWiz.SWizardName := SWizardName;
  WizMenuAct.BaseWiz.SWizardID := SWizardID;
  WizMenuAct.BaseWiz.CreateInstFunc := CreateInstFunc;

end.
