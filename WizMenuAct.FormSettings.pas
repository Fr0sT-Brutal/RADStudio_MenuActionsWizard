unit WizMenuAct.FormSettings;

interface

uses
  SysUtils, Classes, Windows, Controls, Forms, StdCtrls, ExtCtrls, ComCtrls,
  Winapi.CommCtrl, StrUtils, Menus, Graphics,
  WizMenuAct.VirtualTrees,
  WizMenuAct.Main, WizMenuAct.BaseWiz;

type
  // intermediate storage for modifications
  TActionEditInfo = record
    SrcInfo: PActionInfo;   // original data
    NewShortcut: TShortCut; // newly assigned shortcut
  end;
  PActionEditInfo = ^TActionEditInfo;

  // Some values for the options frame, saved in registry
  TFrameOptions = record
    ColWidths: array[0..3] of Integer;
  end;

  TfrmSettings = class(TFrame)
    Panel1: TPanel;
    Panel2: TPanel;
    Panel3: TPanel;
    lblDescr: TLabel;
    PopupMenu1: TPopupMenu;
    miRevert: TMenuItem;
    miClearDef: TMenuItem;
    eFilter: TEdit;
    lblShortcutUsed: TLabel;
    procedure miRevertClick(Sender: TObject);
    procedure miClearDefClick(Sender: TObject);
    procedure eFilterChange(Sender: TObject);
    procedure vstActionsCompareNodes(Sender: TBaseVirtualTree; Node1, Node2: PVirtualNode; Column: TColumnIndex; var Result: Integer);
    procedure vstActionsGetText(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
    procedure vstActionsIncrementalSearch(Sender: TBaseVirtualTree; Node: PVirtualNode; const SearchText: string; var Result: Integer);
    procedure vstActionsGetImageIndex(Sender: TBaseVirtualTree; Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex; var Ghosted: Boolean; var ImageIndex: Integer);
    procedure vstActionsKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure lblShortcutUsedClick(Sender: TObject);
    procedure vstActionsFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
  private
    FActions: TList; // pointer to the main actions list
    FEmptyIcon: TBitmap;
    FEmptyIdx: Integer;
    FUsedAction: PActionEditInfo;
    vstActions: TVirtualStringTree;
  public
    procedure Init(Actions: TList);
    procedure Close(Accepted: Boolean);
  end;

var
  // Filled by the wizard on Startup, read by the wizard on cleanup
  FrameOptions: TFrameOptions;

implementation

{$R *.dfm}

resourcestring
  SForm       = 'Settings';
  SLabelDescr = 'Select an item and press a key combination to set custom shortcut.'#13#10+
                'Select one or several items and call context menu for group action.';
  SLabelUsed  = 'Shortcut <%s> is already used for action <%s %s>.'#13#10+
                'Click: go to that action.';
  SEditFilter = 'Filter...';
  SColumn0    = 'Action name';
  SColumn1    = 'Caption';
  SColumn2    = 'Default shortcut';
  SColumn3    = 'Custom shortcut';
  SMenuRevert = 'Revert shortcut to default';
  SMenuClear  = 'Clear default shortcut';
  SNoShortcut = '[No shortcut]';

const
  ColCaptions: array[0..3] of string = (SColumn0, SColumn1, SColumn2, SColumn3);

// ='' if DefShortCut = ShortCut
// ='[No shortcut]' if ShortCut = 0
// =ShortCutToText otherwize
function ShortCutToTextEx(ShortCut, DefShortCut: TShortCut): string;
begin
  if DefShortCut = ShortCut then
    Result := ''
  else if ShortCut = 0 then
    Result := SNoShortcut
  else
    Result := ShortCutToText(ShortCut);
end;

// Called after frame creation
procedure TfrmSettings.Init(Actions: TList);
var
  pAI: PActionInfo;
  pAEI: PActionEditInfo;
  i: Integer;
begin
  FActions := Actions;

  vstActions := TVirtualStringTree.Create(Self);
  with vstActions do
  begin
    Parent := Panel2;
    Align := alClient;
    Header.AutoSizeIndex := 0;
    Header.Options := [hoColumnResize, hoShowSortGlyphs, hoVisible, hoAutoSpring, hoHeaderClickAutoSort];
    Header.SortColumn := 0;
    IncrementalSearch := isVisibleOnly;
    PopupMenu := PopupMenu1;
    ScrollBarOptions.ScrollBars := ssVertical;
    TreeOptions.MiscOptions := TreeOptions.MiscOptions - [toAcceptOLEDrop, toEditOnClick] + [toGridExtensions, toReportMode];
    TreeOptions.PaintOptions := TreeOptions.PaintOptions - [toShowRoot] + [toShowHorzGridLines, toShowVertGridLines];
    TreeOptions.SelectionOptions := [toFullRowSelect, toMultiSelect];

    with Header.Columns.Add do
    begin
      Options := Options - [coDraggable] + [coAutoSpring];
      Width := 200;
    end;
    with Header.Columns.Add do
    begin
      Options := Options - [coDraggable] + [coAutoSpring];
      Width := 200;
    end;
    with Header.Columns.Add do
    begin
      Options := Options - [coDraggable];
      Width := 100;
    end;
    with Header.Columns.Add do
    begin
      Options := Options - [coDraggable];
      Width := 130;
    end;

    OnCompareNodes := vstActionsCompareNodes;
    OnFreeNode := vstActionsFreeNode;
    OnGetText := vstActionsGetText;
    OnGetImageIndex := vstActionsGetImageIndex;
    OnIncrementalSearch := vstActionsIncrementalSearch;
    OnKeyUp := vstActionsKeyUp;
  end;

  // init controls labels
  Caption := SForm;
  lblDescr.Caption := SLabelDescr;
  eFilter.TextHint := SEditFilter;
  for i := 0 to Length(ColCaptions) - 1 do
    vstActions.Header.Columns[i].Text := ColCaptions[i];
  miRevert.Caption := SMenuRevert;
  miClearDef.Caption := SMenuClear;

  // apply options
  for i := Low(FrameOptions.ColWidths) to High(FrameOptions.ColWidths) do
    if FrameOptions.ColWidths[i] <> 0 then
      vstActions.Header.Columns[i].Width := FrameOptions.ColWidths[i];

  FEmptyIcon := TBitmap.Create;
  FEmptyIcon.Width := INSrv.ActionList.Images.Width;
  FEmptyIcon.Height := INSrv.ActionList.Images.Height;
  FEmptyIdx := INSrv.ActionList.Images.Add(FEmptyIcon, nil);

  // fill action list
  vstActions.NodeDataSize := SizeOf(Pointer);
  vstActions.BeginUpdate;
  for pAI in FActions do
  begin
    // one-time assignment
    if vstActions.Images = nil then
      vstActions.Images := pAI.Action.ActionList.Images;
    New(pAEI);
    pAEI.SrcInfo := pAI;
    pAEI.NewShortcut := pAI.CustShortcut;
    vstActions.AddChild(nil, pAEI);
  end;
  vstActions.EndUpdate;
end;

// Called on Options dialog close
procedure TfrmSettings.Close(Accepted: Boolean);
var
  node: PVirtualNode;
  pAEI: PActionEditInfo;
  i: Integer;
begin
  // save modifications
  if Accepted then
    for node in vstActions.ChildNodes(nil) do
    begin
      pAEI := PActionEditInfo(vstActions.GetNodeData(node)^);
      if pAEI.SrcInfo.CustShortcut <> pAEI.NewShortcut then
        pAEI.SrcInfo.CustShortcut := pAEI.NewShortcut;
    end;

  // save frame options
  for i := Low(FrameOptions.ColWidths) to High(FrameOptions.ColWidths) do
    FrameOptions.ColWidths[i] := vstActions.Header.Columns[i].Width;

  INSrv.ActionList.Images.Delete(FEmptyIdx);
  FreeAndNil(FEmptyIcon);
end;

// *** child control event handlers ***

procedure TfrmSettings.lblShortcutUsedClick(Sender: TObject);
var
  node: PVirtualNode;
begin
  if FUsedAction = nil then Exit;

  for node in vstActions.ChildNodes(nil) do
    if PActionEditInfo(vstActions.GetNodeData(node)^) = FUsedAction then
    begin
      vstActions.FocusedNode := node;
      vstActions.ClearSelection;
      vstActions.Selected[node] := True;
      // clear property and hide label
      FUsedAction := nil;
      lblShortcutUsed.Visible := False;
      Break;
    end;
end;

// Filter nodes
procedure TfrmSettings.eFilterChange(Sender: TObject);
var
  col: Integer;
  filter: string;
  currnode, node: PVirtualNode;
  filtered: Boolean;
begin
  filter := AnsiUpperCase((Sender as TEdit).Text);
  currnode := vstActions.FocusedNode;

  // empty filter - show all
  if filter = '' then
  begin
    for node in vstActions.ChildNodes(nil) do
      vstActions.IsFiltered[node] := False;
    Exit;
  end;
  // filter by all columns
  for node in vstActions.ChildNodes(nil) do
  begin
    filtered := True;
    for col := 0 to vstActions.Header.Columns.Count - 1 do
      if ContainsStr(AnsiUpperCase(vstActions.Text[node, col]), filter) then
      begin
        filtered := False;
        Break;
      end;
      vstActions.IsFiltered[node] := filtered;
  end;

  // if focused node was filtered out (became invisible), focus the nearest visible
  if currnode <> nil then
  begin
    if vstActions.IsFiltered[currnode] then
    begin
      with vstActions do
        if GetNextVisible(currnode) <> nil
          then currnode := GetNextVisible(currnode)
          else currnode := GetPreviousVisible(currnode);
      if currnode <> nil then
        vstActions.FocusedNode := currnode;
    end;
    // jump to the focused one anyway (mainly actual when deleting or widening a filter
    // when previously hidden nodes get shown and the focused one moves far far away
    vstActions.ScrollIntoView(vstActions.FocusedNode, True);
  end;

  vstActions.EndUpdate;
end;

// Set custom shortcut to none
procedure TfrmSettings.miClearDefClick(Sender: TObject);
var
  node: PVirtualNode;
  pAEI: PActionEditInfo;
begin
  for node in vstActions.SelectedNodes do
  begin
    pAEI := PActionEditInfo(vstActions.GetNodeData(node)^);
    pAEI.NewShortcut := 0;
    vstActions.RepaintNode(node);
  end;
end;

// Revert custom shortcut to default
procedure TfrmSettings.miRevertClick(Sender: TObject);
var
  node: PVirtualNode;
  pAEI: PActionEditInfo;
begin
  for node in vstActions.SelectedNodes do
  begin
    pAEI := PActionEditInfo(vstActions.GetNodeData(node)^);
    pAEI.NewShortcut := pAEI.SrcInfo.DefShortcut;
    vstActions.RepaintNode(node);
  end;
end;

// Sort callback. Compare displayed strings witout case sensivity
procedure TfrmSettings.vstActionsCompareNodes(Sender: TBaseVirtualTree; Node1, Node2: PVirtualNode; Column: TColumnIndex; var Result: Integer);
begin
  Result := CompareText(TVirtualStringTree(Sender).Text[Node1, Column], TVirtualStringTree(Sender).Text[Node2, Column]);
end;

procedure TfrmSettings.vstActionsFreeNode(Sender: TBaseVirtualTree; Node: PVirtualNode);
begin
  Dispose(PActionEditInfo(Sender.GetNodeData(Node)^));
end;

// Display action icon
procedure TfrmSettings.vstActionsGetImageIndex(Sender: TBaseVirtualTree; Node: PVirtualNode; Kind: TVTImageKind; Column: TColumnIndex; var Ghosted: Boolean; var ImageIndex: Integer);
var
  pAEI: PActionEditInfo;
begin
  if Column <> 0 then Exit; // 1st column only
  pAEI := PActionEditInfo(Sender.GetNodeData(Node)^);
  ImageIndex := pAEI.SrcInfo.Action.ImageIndex;
  if ImageIndex = -1 then
    ImageIndex := FEmptyIdx;
end;

// Return displayable captions
procedure TfrmSettings.vstActionsGetText(Sender: TBaseVirtualTree; Node: PVirtualNode; Column: TColumnIndex; TextType: TVSTTextType; var CellText: string);
var
  pAEI: PActionEditInfo;
begin
  pAEI := PActionEditInfo(Sender.GetNodeData(Node)^);
  case Column of
    0: CellText := pAEI.SrcInfo.Name;
    1: CellText := StripHotkey(pAEI.SrcInfo.Caption);  // removing "&"
    2: CellText := ShortCutToText(pAEI.SrcInfo.DefShortcut);
    3: CellText := ShortCutToTextEx(pAEI.NewShortcut, pAEI.SrcInfo.DefShortcut);
  end;
end;

// Go to first node in current sort column
procedure TfrmSettings.vstActionsIncrementalSearch(Sender: TBaseVirtualTree; Node: PVirtualNode; const SearchText: string; var Result: Integer);
begin
  with TVirtualStringTree(Sender) do
    if (Header.SortColumn = NoColumn) or Sender.IsFiltered[Node] then
      Result := 1
    else
      if AnsiSameText(LeftStr(Text[Node, Header.SortColumn], Length(SearchText)),
                      SearchText)
        then Result := 0
        else Result := 1;
end;

// keystrokes with modifiers set custom shortcuts of a focused item
procedure TfrmSettings.vstActionsKeyUp(Sender: TObject; var Key: Word; Shift: TShiftState);
var
  pAEI: PActionEditInfo;
  node: PVirtualNode;
  NewShortcut: TShortCut;
begin
  // set custom shortcut (to a single focused item)
  if (Shift <> []) then
    case Key of
      0, VK_SHIFT, VK_CONTROL, VK_MENU: // modifiers only - let it pass
        ;
      else
      with TBaseVirtualTree(Sender) do
      begin
        if FocusedNode = nil then Exit;
        NewShortcut := ShortCut(Key, Shift);
        // check if this shortcut is already used
        for node in ChildNodes(nil) do
          if node <> FocusedNode then // pass the node itself
          begin
            pAEI := PActionEditInfo(GetNodeData(node)^);
            if pAEI.NewShortcut = NewShortcut then
            begin
              FUsedAction := pAEI;
              lblShortcutUsed.Caption :=
                Format(SLabelUsed, [ShortCutToText(NewShortcut), pAEI.SrcInfo.Name, pAEI.SrcInfo.Caption]);
              lblShortcutUsed.Visible := True;
              Exit;
            end;
          end;
        // set the shortcut
        pAEI := PActionEditInfo(GetNodeData(FocusedNode)^);
        pAEI.NewShortcut := NewShortcut;
        RepaintNode(FocusedNode);
        lblShortcutUsed.Visible := False;
        FUsedAction := nil;
        Key := 0;
      end; // with
    end; // case
end;

end.
