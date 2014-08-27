Menu action shortcuts expert/wizard for RAD Studio 2009+
========================================================

Features
--------

* Assign and modify shortcuts for most used actions
* Integrates into IDE options page

Installation
------------

Sorry, no binaries here - they're individual for each IDE version so you'll have to build the wizard yourself.

1. Grab the last version from `RADStudio_BaseWizard` repository nearby.
2. Grab the last version from this repository.
3. Open `WizFavoritesP.dproj` in RAD studio and go `Project > Options... > Delphi compiler`, add a path to BaseWizard units to the field **Search path**.
4. Compile and install.

Warning
-------

Right after rebuilding the wizard there's numerous AV's in rtl160.bpl when opening `Options` dialog (at least in XE2). They're gone after IDE restart anyway so there's nothing to worry about.

![](./screenshots/1.png?raw=true)