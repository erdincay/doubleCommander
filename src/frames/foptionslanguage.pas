{
   Double Commander
   -------------------------------------------------------------------------
   Language options page

   Copyright (C) 2006-2014 Alexander Koblov (alexx2000@mail.ru)

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

unit fOptionsLanguage;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StdCtrls,
  fOptionsFrame;

type

  { TfrmOptionsLanguage }

  TfrmOptionsLanguage = class(TOptionsEditor)
    lngList: TListBox;
  private
    procedure FillLngListBox;
  protected
    procedure Load; override;
    function Save: TOptionsEditorSaveFlags; override;
  public
    class function GetIconIndex: Integer; override;
    class function GetTitle: String; override;
  end;

implementation

{$R *.lfm}

uses
  uDebug, uFindEx, uGlobs, uGlobsPaths, uLng;

{ TfrmOptionsLanguage }

procedure TfrmOptionsLanguage.FillLngListBox;
var
  fr: TSearchRecEx;
  iIndex: Integer;
  sLangName: String;
  LanguageFileList: TStringList;
begin
  LanguageFileList:=TStringList.Create;
  LanguageFileList.Sorted:=True;
  LanguageFileList.Duplicates:=dupAccept;
  try
    lngList.Clear;
    DCDebug('Language directory: ' + gpLngDir);
    if FindFirstEx(gpLngDir + '*.po', faAnyFile, fr) = 0 then
    repeat
      sLangName := GetLanguageName(gpLngDir + fr.Name);
      LanguageFileList.Add(Format('%s = %s', [sLangName, fr.Name]));
    until FindNextEx(fr) <> 0;
    FindCloseEx(fr);

    for iIndex:=0 to pred(LanguageFileList.Count) do
    begin
      lngList.Items.add(LanguageFileList.Strings[iIndex]);
      if (gPOFileName = Trim(lngList.Items.ValueFromIndex[iIndex])) then lngList.ItemIndex:=iIndex;
    end;

  finally
    LanguageFileList.Free;
  end;
end;

class function TfrmOptionsLanguage.GetIconIndex: Integer;
begin
  Result := 0;
end;

class function TfrmOptionsLanguage.GetTitle: String;
begin
  Result := rsOptionsEditorLanguage;
end;

procedure TfrmOptionsLanguage.Load;
begin
  FillLngListBox;
end;

function TfrmOptionsLanguage.Save: TOptionsEditorSaveFlags;
var
  SelectedPOFileName: String;
begin
  Result := [];
  if lngList.ItemIndex > -1 then
  begin
    SelectedPOFileName := Trim(lngList.Items.ValueFromIndex[lngList.ItemIndex]);
    if SelectedPOFileName <> gPOFileName then
      Include(Result, oesfNeedsRestart);
    gPOFileName := SelectedPOFileName;
  end;
end;

end.

