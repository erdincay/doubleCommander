{
   Double Commander
   -------------------------------------------------------------------------
   Implementing of Options dialog

   Copyright (C) 2006-2011  Koblov Alexander (Alexx2000@mail.ru)

   contributors:

   Radek Cervinka  <radek.cervinka@centrum.cz>

   This program is free software; you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 2 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program; if not, write to the Free Software
   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

unit fOptions;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Controls, Forms, Dialogs, ExtCtrls, ComCtrls, Buttons,
  StdCtrls, fgl, uGlobs, fOptionsFrame, uDCUtils;

type

  { TOptionsEditorView }

  TOptionsEditorView = class
    EditorClass: TOptionsEditorClass;
    Instance: TOptionsEditor;
    TreeNode: TTreeNode;
    LegacyOrderIndex: integer;
  end;

  TOptionsEditorViews = specialize TFPGObjectList<TOptionsEditorView>;

  { TfrmOptions }

  TfrmOptions = class(TForm, IOptionsDialog)
    lblEmptyEditor: TLabel;
    OptionsEditorsImageList: TImageList;
    Panel1: TPanel;
    Panel3: TPanel;
    pnlCaption: TPanel;
    btnOK: TBitBtn;
    btnApply: TBitBtn;
    btnCancel: TBitBtn;
    sboxOptionsEditor: TScrollBox;
    tvTreeView: TTreeView;
    splOptionsSplitter: TSplitter;
    procedure btnCancelClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
    procedure btnOKClick(Sender: TObject);
    procedure btnApplyClick(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure tvTreeViewChange(Sender: TObject; Node: TTreeNode);
  private
    FOptionsEditorList: TOptionsEditorViews;
    FOldEditor: TOptionsEditorView;
    function CreateEditor(EditorClass: TOptionsEditorClass): TOptionsEditor;
    procedure CreateOptionsEditorList;
    function GetEditor(EditorClass: TOptionsEditorClass): TOptionsEditor;
    procedure LoadSettings;
    procedure SelectEditor(EditorClassName: String);
    function CompareTwoNodeOfConfigurationOptionTree(Node1, Node2: TTreeNode): integer;
  public
    constructor Create(TheOwner: TComponent); override;
    constructor Create(TheOwner: TComponent; EditorClass: TOptionsEditorClass); overload;
    constructor Create(TheOwner: TComponent; EditorClassName: String); overload;
    procedure LoadConfig;
    procedure SaveConfig;
  end;

  function ShowOptions(EditorClass: TOptionsEditorClass = nil): IOptionsDialog;
  function ShowOptions(EditorClassName: String): IOptionsDialog;
  procedure SortConfigurationOptionsOnLeftTree; //If the var "frmOptions" would be in the interface section, we could have called directly "frmOptions.tvTreeView.CustomSort(@frmOptions.CompareTwoNodeOfConfigurationOptionTree);"
                                                //But it's not the case... Let's create this routine and respect the wish of original authors to have it there. Maybe there is a raison why so let's play safe.

implementation

{$R *.lfm}

uses
  LCLProc, LCLVersion, uLng, fMain;

var
  LastOpenedEditor: TOptionsEditorClass = nil;
  frmOptions: TfrmOptions = nil;

function ShowOptions(EditorClass: TOptionsEditorClass): IOptionsDialog;
begin
  Result := ShowOptions(EditorClass.ClassName);
end;

function ShowOptions(EditorClassName: String): IOptionsDialog;
begin
  if Assigned(frmOptions) then
    begin
      if frmOptions.WindowState = wsMinimized then
        frmOptions.WindowState:= wsNormal
      else
        frmOptions.BringToFront;

      frmOptions.SelectEditor(EditorClassName);
    end
  else
    begin
      if EditorClassName = '' then
        frmOptions := TfrmOptions.Create(Application)
      else
        frmOptions := TfrmOptions.Create(Application, EditorClassName);

      frmOptions.Show;
  end;
  Result := frmOptions;
end;

procedure SortConfigurationOptionsOnLeftTree;
begin
  if frmOptions<>nil then frmOptions.tvTreeView.CustomSort(@frmOptions.CompareTwoNodeOfConfigurationOptionTree);
end;

procedure TfrmOptions.FormCreate(Sender: TObject);
begin
  // Initialize property storage
  InitPropStorage(Self);
end;

procedure TfrmOptions.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  CloseAction:= caFree;
  frmOptions:= nil;
end;

procedure TfrmOptions.FormCloseQuery(Sender: TObject; var CanClose: boolean);
var
  I:integer;
  NeedsUpdateWindowView:boolean=FALSE;
begin
  CanClose:=TRUE;
  I:=0;
  while (I<FOptionsEditorList.Count) AND (CanClose) do
  begin
    if Assigned(FOptionsEditorList[I].Instance) then CanClose:=FOptionsEditorList[I].Instance.CanWeClose(NeedsUpdateWindowView);
    inc(I);
  end;

  if NeedsUpdateWindowView then frmMain.UpdateWindowView;
end;

procedure TfrmOptions.btnCancelClick(Sender: TObject);
begin
  // close window
  Close;
end;

procedure TfrmOptions.btnOKClick(Sender: TObject);
begin
  // save all configuration
  SaveConfig;
  // write to config file
  SaveGlobs;
  // close window
  Close;
end;

procedure TfrmOptions.btnApplyClick(Sender: TObject);
begin
  // save all configuration
  SaveConfig;
  // write to config file
  SaveGlobs;
end;

procedure TfrmOptions.FormDestroy(Sender: TObject);
begin
  FreeThenNil(FOptionsEditorList);
end;

function TfrmOptions.CompareTwoNodeOfConfigurationOptionTree(Node1, Node2: TTreeNode): integer;
begin
  case gSortOrderOfConfigurationOptionsTree of
    scoClassicLegacy:
      begin
        if TOptionsEditorView(Node1.Data).LegacyOrderIndex < TOptionsEditorView(Node2.Data).LegacyOrderIndex then result:=-1 else result:=1;
      end;

    scoAlphabeticalButLanguage:
      begin
        if TOptionsEditorView(Node1.Data).EditorClass.ClassName='TfrmOptionsLanguage' then
          result:=-1
        else
          if TOptionsEditorView(Node2.Data).EditorClass.ClassName='TfrmOptionsLanguage' then
            result:=1
          else
            result:=CompareStrings(Node1.Text,Node2.Text, gSortNatural, gSortCaseSensitivity)
      end;
  end;

end;

procedure TfrmOptions.CreateOptionsEditorList;
  procedure AddEditors(EditorClassList: TOptionsEditorClassList; RootNode: TTreeNode);
  var
    I: LongInt;
    aOptionsEditorClass: TOptionsEditorClass;
    aOptionsEditorView: TOptionsEditorView;
    TreeNode: TTreeNode;
    IconIndex: Integer;
  begin
    for I:= 0 to EditorClassList.Count - 1 do
    begin
      aOptionsEditorClass := EditorClassList[I].EditorClass;

      aOptionsEditorView := TOptionsEditorView.Create;
      aOptionsEditorView.EditorClass := aOptionsEditorClass;
      aOptionsEditorView.Instance    := nil;
      aOptionsEditorView.LegacyOrderIndex:=I;
      FOptionsEditorList.Add(aOptionsEditorView);

      TreeNode := tvTreeView.Items.AddChild(RootNode,
{$IF lcl_fullversion >= 093100}
        aOptionsEditorClass.GetTitle
{$ELSE}
        StringReplace(aOptionsEditorClass.GetTitle, '&', '&&', [rfReplaceAll])
{$ENDIF}
        );
      if Assigned(TreeNode) then
      begin
        IconIndex := aOptionsEditorClass.GetIconIndex;
        TreeNode.ImageIndex    := IconIndex;
        TreeNode.SelectedIndex := IconIndex;
        TreeNode.StateIndex    := IconIndex;
        TreeNode.Data          := aOptionsEditorView;
      end;

      aOptionsEditorView.TreeNode := TreeNode;

      if EditorClassList[I].HasChildren then
        AddEditors(EditorClassList[I].Children, TreeNode);
    end;

    //2014-08-12:Let's sort by alphabetical order this list.
    tvTreeView.CustomSort(@CompareTwoNodeOfConfigurationOptionTree);
  end;
begin
  FOptionsEditorList:= TOptionsEditorViews.Create;
  AddEditors(OptionsEditorClassList, nil);
end;

function TfrmOptions.GetEditor(EditorClass: TOptionsEditorClass): TOptionsEditor;
var
  I: Integer;
begin
  for I := 0 to FOptionsEditorList.Count - 1 do
  begin
    if FOptionsEditorList[I].EditorClass = EditorClass then
    begin
      if not Assigned(FOptionsEditorList[I].Instance) then
        FOptionsEditorList[I].Instance := CreateEditor(FOptionsEditorList[I].EditorClass);
      Result := FOptionsEditorList[I].Instance;
      Exit;
    end;
  end;
  Result := nil;
end;

procedure TfrmOptions.LoadSettings;
begin
  LoadConfig;
end;

procedure TfrmOptions.SelectEditor(EditorClassName: String);
var
  I: Integer;
begin
  for I := 0 to FOptionsEditorList.Count - 1 do
  begin
    if (FOptionsEditorList[I].EditorClass.ClassName = EditorClassName) then
      if Assigned(FOptionsEditorList[I].TreeNode) then
      begin
        FOptionsEditorList[I].TreeNode.Selected := True;
        Break;
      end;
  end;
end;

constructor TfrmOptions.Create(TheOwner: TComponent);
begin
  if not Assigned(LastOpenedEditor) and (OptionsEditorClassList.Count > 0) then
    LastOpenedEditor := OptionsEditorClassList[0].EditorClass; // Select first editor.
  Create(TheOwner, LastOpenedEditor);
end;

constructor TfrmOptions.Create(TheOwner: TComponent; EditorClass: TOptionsEditorClass);
begin
  if Assigned(EditorClass) then
    Create(TheOwner, EditorClass.ClassName)
  else
    Create(TheOwner, '');
end;

constructor TfrmOptions.Create(TheOwner: TComponent; EditorClassName: String);
begin
  if (EditorClassName = '') and Assigned(LastOpenedEditor) then
    EditorClassName := LastOpenedEditor.ClassName;
  FOldEditor := nil;
  inherited Create(TheOwner);
  CreateOptionsEditorList;
  SelectEditor(EditorClassName);
end;

procedure TfrmOptions.tvTreeViewChange(Sender: TObject; Node: TTreeNode);
var
  SelectedEditorView: TOptionsEditorView;
begin
  SelectedEditorView := TOptionsEditorView(Node.Data);

  if Assigned(SelectedEditorView) and (FOldEditor <> SelectedEditorView) then
  begin
    if Assigned(FOldEditor) and Assigned(FOldEditor.Instance) then
      FOldEditor.Instance.Visible := False;

    if not Assigned(SelectedEditorView.Instance) then
      SelectedEditorView.Instance := CreateEditor(SelectedEditorView.EditorClass);

    if Assigned(SelectedEditorView.Instance) then
      SelectedEditorView.Instance.Visible := True;

    lblEmptyEditor.Visible := not Assigned(SelectedEditorView.Instance);

    FOldEditor := SelectedEditorView;
    LastOpenedEditor := SelectedEditorView.EditorClass;

    pnlCaption.Caption := SelectedEditorView.EditorClass.GetTitle;
  end;
end;

function TfrmOptions.CreateEditor(EditorClass: TOptionsEditorClass): TOptionsEditor;
begin
  if Assigned(EditorClass) and not EditorClass.IsEmpty then
  begin
    Result := EditorClass.Create(Self);
    Result.Align   := alClient;
    Result.Visible := False;
    Result.Init(sboxOptionsEditor, Self, [oeifLoad]);
  end
  else
    Result := nil;
end;

procedure TfrmOptions.LoadConfig;
var
  I: LongInt;
begin
  { Load options to frames }
  for I:= 0 to FOptionsEditorList.Count - 1 do
  begin
    if Assigned(FOptionsEditorList[I].Instance) then
      FOptionsEditorList[I].Instance.LoadSettings;
  end;
end;

procedure TfrmOptions.SaveConfig;
var
  I: LongInt;
  NeedsRestart: Boolean = False;
begin
  { Save options from frames }
  for I:= 0 to FOptionsEditorList.Count - 1 do
  begin
    if Assigned(FOptionsEditorList[I].Instance) then
    try
      if oesfNeedsRestart in FOptionsEditorList[I].Instance.SaveSettings then
        NeedsRestart := True;
    except
      on E: Exception do
        MessageDlg(FOptionsEditorList[I].Instance.GetTitle, E.Message, mtError, [mbOK], 0);
    end;
  end;

  if NeedsRestart then
    MessageDlg(rsMsgRestartForApplyChanges, mtInformation, [mbOK], 0);

  frmMain.UpdateWindowView;
end;

end.
