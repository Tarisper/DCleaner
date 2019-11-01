unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants,
  System.Classes, System.UITypes, Vcl.Graphics, Vcl.Controls, Vcl.Forms,
  Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls, System.Actions, Vcl.ActnList,
  Vcl.Menus, Vcl.StdActns, Vcl.ComCtrls, DateUtils, Vcl.ToolWin,
  System.ImageList, Vcl.ImgList, Vcl.VirtualImageList, Vcl.BaseImageCollection,
  Vcl.ImageCollection;

const
  MAX_LENGTH_PATH = 55;
  MAX_LINES_COUNT = 500;
  MAX_AGE = 1440;
  DEL_INTERVAL = 10;
  DEF_PREF = 'log_';

type
  TMForm = class(TForm)
    btnStartStop: TButton;
    btnReloadIni: TButton;
    Panel1: TPanel;
    triIcon: TTrayIcon;
    pmTrayMenu: TPopupMenu;
    alComm: TActionList;
    acShowHide: TAction;
    N1: TMenuItem;
    acExit: TAction;
    N2: TMenuItem;
    N3: TMenuItem;
    Panel2: TPanel;
    btnHide: TButton;
    MMenu: TMainMenu;
    N4: TMenuItem;
    N5: TMenuItem;
    N6: TMenuItem;
    acAbout: TAction;
    N7: TMenuItem;
    reLog: TRichEdit;
    tmrClear: TTimer;
    acPauseStart: TAction;
    ImageCollection1: TImageCollection;
    VirtualImageList1: TVirtualImageList;
    ToolBar1: TToolBar;
    ToolButton1: TToolButton;
    ToolButton2: TToolButton;
    acReReadSett: TAction;
    ToolButton3: TToolButton;
    acStop: TAction;
    ToolButton4: TToolButton;
    sbBar: TStatusBar;
    N8: TMenuItem;
    N9: TMenuItem;
    acWriteLog: TAction;
    procedure FormCreate(Sender: TObject);
    procedure acExitExecute(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure tmrClearTimer(Sender: TObject);
    procedure acPauseStartExecute(Sender: TObject);
    procedure acShowHideExecute(Sender: TObject);
    procedure acStopExecute(Sender: TObject);
    procedure acReReadSettExecute(Sender: TObject);
    procedure acAboutExecute(Sender: TObject);
    procedure acWriteLogExecute(Sender: TObject);
  private
    { Private declarations }
    function ReadIniFiles: Boolean;
    function GetInfo(sFileName: string): string;
    procedure CreateDelTread;
    function MinToTime(iMin: Integer): string;
    procedure WriteToFile(sPath, sText: string);
    procedure WriteLogFile(sText: string);
  public
    { Public declarations }
    procedure AddToLog(sValue: string; bAddDateTime: Boolean = True; fsStyle:
      TFontStyles = []; Color: Integer = 0);
    function IntToBool(iValue: Integer): Boolean;
  end;

type
  TAppSettings = record
    sIniPath: string;
    bShowWindows: Boolean;
    bWriteLog: Boolean;
    sPathLog: string;
    sLogPref: string;
    iStartInterval: Integer;
    iDelInterval: Integer;
    bShowConsole: Boolean;
  end;

type
  TDirSettings = record
    Name: string;
    Filter: string;
    Age: Integer;
  end;

type
  TFilesSettings = record
    Values: TStringList;
    Settings: array of TDirSettings;
  end;

  TDelThread = class(TThread)
  private
    { Private declarations }
    procedure DelFiles(sPath, sFilter: string; iAge: Integer);
    procedure WriteCount(iNum, iCount: Integer);
  protected
    procedure Execute; override;
  end;

var
  MForm: TMForm;
  AppSett: TAppSettings;
  FilesSett: TFilesSettings;
  bSecondLoad: Boolean;
  DelThread: TDelThread;
  bPause: Boolean;
  bStop: Boolean;
  bLogExist: Boolean;
  slToDel: TStringList;

implementation

uses
  uDataModule, uAbout;

{$R *.dfm}

procedure TDelThread.DelFiles(sPath, sFilter: string; iAge: Integer);
var
  j, iDelCount, Attr: Integer;
  tsFA: TDateTime;
  iMinuts: Integer;
  sSumPath: string;
  iDel, iNotDel: Integer;

  function GetDirTime(const aPath: string): TDateTime;
  var
    H: Integer;
    F: TFileTime;
    S: TSystemTime;
  begin
    H := CreateFile(PChar(aPath), $0080, 0, nil, OPEN_EXISTING,
      FILE_FLAG_BACKUP_SEMANTICS, 0);
    if H <> -1 then
    begin
      GetFileTime(H, @F, nil, nil);
      FileTimeToLocalFileTime(F, F);
      FileTimeToSystemTime(F, S);
      Result := SystemTimeToDateTime(S);
      CloseHandle(H);
    end
    else
      Result := -1;
  end;

  function IsDirEmpty(const aPath: string): Boolean;
  var
    fs: TSearchRec;
    aaPath: string;
  begin
    Result := True;
    aaPath := IncludeTrailingPathDelimiter(aPath);
    if FindFirst(aaPath + '*.*', faAnyFile, fs) = 0 then
      repeat
        if (fs.Name <> '.') and (fs.Name <> '..') then
        begin
          Result := False;
          FindClose(fs);
          Exit;
        end;
      until FindNext(fs) <> 0;
    FindClose(fs);
  end;

  procedure EnumFiles(const aPath, aFilter: string; const aAttr: Integer; aSl:
    TStringList);
  var
    Sr: TSearchRec;
    Attr: Integer;
    sPath, sExt: string;
  begin
    // ���� � �����. ��������� � ���� ����������� ����, ���� ��� ���.
    sPath := IncludeTrailingPathDelimiter(aPath);
    // ��������� ������� �����.
    Attr := aAttr or faDirectory;
    try
      if FindFirst(sPath + '*', Attr, Sr) = 0 then
        repeat
          // ���� ������� �����, �� ��������� ��� �� ����������� �����.
          if faDirectory = (Sr.Attr and faDirectory) then
          begin
            // ���������� ������ �� ������� � ������������ ��������.
            if (Sr.Name = '.') or (Sr.Name = '..') then
              Continue;
            // ����������� �����.
            tsFA := GetDirTime(Sr.Name);
            iMinuts := MinutesBetween(tsFA, Now);
            // ��������� �������� "������" ��� iAge.
            if (iMinuts >= iAge) then
            begin
              if not IsDirEmpty(sPath + Sr.Name) then
                EnumFiles(sPath + Sr.Name + '\', aFilter, aAttr, aSl);
              aSl.Add(IncludeTrailingPathDelimiter(sPath + Sr.Name));
            end;
            Continue;
          end;
          // ���������� ���������� �����.
          sExt := AnsiUpperCase(ExtractFileExt(Sr.Name));
          // ����������� �� ���������� ������ �������� ����������.
          sFilter := Copy(sFilter, Pos('.', sFilter), Length(sFilter) - Pos('.',
            sFilter) + 1);
          if (sExt <> AnsiUpperCase(sFilter)) and (Pos('*', sFilter) = 0) then
            Continue;
          // ��������� ��������� ���� � ������.
          if FileExists(Sr.Name) then
            FileAge(Sr.Name, tsFA)
          else
            tsFA := GetDirTime(Sr.Name);
          iMinuts := MinutesBetween(tsFA, Now);
          if (iMinuts >= iAge) or (faDirectory = (Sr.Attr and faDirectory))
            then
          begin
            aSl.Add(sPath + Sr.Name);
          end;
        until FindNext(Sr) <> 0;
      FindClose(Sr);
    except
    end;
  end;

begin
  iDel := 0;
  iNotDel := 0;
  if MForm.reLog.Lines.Count > MAX_LINES_COUNT then
    MForm.reLog.Clear;
  sSumPath := '�������: ' + sPath;
  if Length(sSumPath) > MAX_LENGTH_PATH then
    MForm.sbBar.Panels.Items[2].Text := Copy(sSumPath, 1, MAX_LENGTH_PATH) +
      '...'
  else
    MForm.sbBar.Panels.Items[2].Text := sSumPath;
  MForm.AddToLog('', False);
  MForm.AddToLog('������� ���� ' + sPath + sFilter, True);
  MForm.AddToLog('������� ������ � ���������� �� ' + MForm.MinToTime(iAge) +
    ' � ������', True);
  SetCurrentDir(sPath);
{$IFDEF DEBUG}
  // Sleep(3000);
{$ENDIF}
  Attr := faAnyFile - faDirectory;
  slToDel := TStringList.Create;
  EnumFiles(sPath, sFilter, Attr, slToDel);
  MForm.AddToLog('������� ������ � ����������: ' + IntTOStr(slToDel.Count),
    True);
  iDelCount := 0;
  MForm.AddToLog('����� �������', True, [fsBold]);
  for j := 0 to slToDel.Count - 1 do
  begin
    try
      if not DirectoryExists(slToDel[j]) then
      begin
        if DeleteFile(slToDel[j]) then
          Inc(iDel)
        else
          Inc(iNotDel);
      end
      else if RemoveDir(slToDel[j]) then
        Inc(iDel)
      else
        Inc(iNotDel);
      Inc(iDelCount);
      if ((j mod 2000) = 0) and (j > 0) then
        MForm.AddToLog('������� ������������. ������� ������ � ����������: ' +
          IntToStr(iDel), True);
      Sleep(AppSett.iDelInterval);
    except
    end;
  end;
  FreeAndNil(slToDel);
  { if FindFirst(sFilter, faAnyFile, searchResult) = 0 then
    begin
    repeat
    if DelThread.Terminated then
    Break;
    if (searchResult.Attr and faDirectory) <> faDirectory then
    begin
    FileAge(searchResult.Name, tsFA);
    iMinuts := MinutesBetween(tsFA, Now);
    if iMinuts >= iAge then
    begin
    try
    // DeleteFile(searchResult.name);
    except
    end;
    Sleep(AppSett.iDelInterval);
    Inc(iCount);
    end;
    end;
    until FindNext(searchResult) <> 0;
    FindClose(searchResult);
    end; }
  MForm.sbBar.Panels.Items[2].Text := '';
  MForm.AddToLog('������� ���������. �������: ' + IntToStr(iDel), True, [fsBold],
    $0041D739);
  if iNotDel > 0 then
    MForm.AddToLog('�� ������� �������: ' + IntToStr(iNotDel), True, [fsBold],
      clRed);
end;

procedure TDelThread.WriteCount(iNum, iCount: Integer);
begin
  MForm.AddToLog('������ ' + IntTOStr(iNum) + ' �� ' + IntToStr(iCount) +
    ' ��������', True);
end;

procedure TDelThread.Execute;
var
  iNum: Integer;
begin
  Sleep(AppSett.iDelInterval);
  for iNum := Low(FilesSett.Settings) to High(FilesSett.Settings) do
  begin
    DelFiles(FilesSett.Settings[iNum].Name, FilesSett.Settings[iNum].Filter,
      FilesSett.Settings[iNum].Age);
    WriteCount(iNum + 1, Length(FilesSett.Settings));
    Sleep(100);
    if DelThread.Terminated then
      Break;
  end;
end;
  // *****************************************************************************
// ������� ����� � ���

  // *****************************************************************************

function TMForm.MinToTime(iMin: Integer): string;
const
  SecPerDay = 86400;
  SecPerHour = 3600;
  SecPerMinute = 60;
var
  iM, iH, iD, iSeconds: Integer;
begin
  iSeconds := iMin * 60;
  iD := iSeconds div SecPerDay;
  iH := (iSeconds mod SecPerDay) div SecPerHour;
  iM := ((iSeconds mod SecPerDay) mod SecPerHour) div SecPerMinute;
  if iD > 0 then
    Result := IntToStr(iD) + ' �.' + IntTOStr(iH) + ' �.' + IntTOStr(iM) +
      ' �.'
  else
  begin
    if iH > 0 then
      Result := IntToStr(iH) + ' �.' + IntTOStr(iM) + ' �.'
    else
      Result := IntToStr(iM) + ' �.';
  end;
end;

function TMForm.IntToBool(iValue: Integer): Boolean;
begin
  if iValue = 0 then
    Result := False
  else
    Result := True;
end;

function TMForm.ReadIniFiles: Boolean;
var
  sAppName: string;
begin
  Result := False;
  sAppName := Application.ExeName;
  if DM.ReadIni(ExtractFilePath(sAppName)) then
  begin
    tmrClear.Enabled := True;
    tmrClear.Interval := 60 * 1000 * AppSett.iStartInterval;
    if bSecondLoad then
      AddToLog('��������� ����������', True, [fsBold], $0041D739)
    else
    begin
      bSecondLoad := True;
      AddToLog('��������� ��������', True, [], $0041D739);
      AddToLog('��������� ���������', True, [], $0041D739);
    end;
    Result := True;
  end
  else
  begin
    acStop.Execute;
    AddToLog('���� [Files] ������� ���������� ����. ��������� ��������:', False,
      [fsBold], clRed);
    AddToLog(' 1. ��������� ����������� ���� ' + AppSett.sIniPath +
      ' �� ������������ ���������� ����������', False, [fsBold], clRed);
    AddToLog(' 2. �������� ��������� � ����������� �� � ������� ������ "���������� ���������"',
      False, [fsBold], clRed);
    AddToLog(' 3. ������� ������ "���������� ������"', False, [fsBold], clRed);
  end;
end;
  // *****************************************************************************
// �������� ������ ��� �������

  // *****************************************************************************

procedure TMForm.CreateDelTread;
begin
  if DelThread = nil then
    DelThread := TDelThread.Create(False)
  else
  begin
    DelThread.Terminate;
    DelThread := TDelThread.Create(False);
  end;
  DelThread.Priority := tpNormal;
end;

procedure TMForm.tmrClearTimer(Sender: TObject);
begin
  MForm.ReadIniFiles;
  CreateDelTread;
end;
  // *****************************************************************************
// �������� ������ ������������ �����

  // *****************************************************************************

function TMForm.GetInfo(sFileName: string): string;
var
  szName: array[0..255] of Char;
  P: Pointer;
  Value: Pointer;
  Len: UINT;
  GetTranslationString: string;
  FFileName, FBuffer: PChar;
  FValid: Boolean;
  FSize, FHandle: DWORD;
begin
  FFileName := nil;
  FSize := 0;
  FHandle := 0;
  FBuffer := nil;
  try
    FFileName := StrPCopy(StrAlloc(Length(sFileName) + 1), sFileName);
    FValid := False;
    FSize := GetFileVersionInfoSize(FFileName, FHandle);
    if FSize > 0 then
    try
      GetMem(FBuffer, FSize);
      FValid := GetFileVersionInfo(FFileName, FHandle, FSize, FBuffer);
    except        // FValid := False;
      raise;
    end;
    Result := '';
    if FValid then
      VerQueryValue(FBuffer, '\VarFileInfo\Translation', P, Len)
    else
      P := nil;
    if P <> nil then
      GetTranslationString := IntToHex(MakeLong(HiWord(Longint(P^)), LoWord(Longint
        (P^))), 8);
    if FValid then
    begin
      StrPCopy(szName, '\StringFileInfo\' + GetTranslationString +
        '\FileVersion');
      if VerQueryValue(FBuffer, szName, Value, Len) then
        Result := StrPas(PChar(Value));
    end;
  finally
    try
      if FBuffer <> nil then
        FreeMem(FBuffer, FSize);
    except
    end;
    try
      StrDispose(FFileName);
    except
    end;
  end;
end;

procedure TMForm.WriteToFile(sPath, sText: string);
var
  tfFile: TextFile;
begin
{$I-}
  if not DirectoryExists(AppSett.sPathLog) then
    ForceDirectories(AppSett.sPathLog);
{$I+}
  AssignFile(tfFile, sPath);
  // ��� ����� ��������� �����,
  // ��������� Exception ��� ������ �����-������
{$I-}
  Append(tfFile); // ��������� ���� ��� ����������� � �����
  if IoResult <> 0 then // ���������, ��� ��������
    // � ������ �������� Exception ��� ������ �����-������
    // ��������� �� ����� ������ �������� �� �����
{$I+}
  try
    ReWrite(tfFile);
  except
  end;
  try
    WriteLn(tfFile, sText); // �����
    CloseFile(tfFile); // ���������
  except
  end;
end;

procedure TMForm.WriteLogFile(sText: string);
var
  sPath: string;
begin
  // if bLogExist then
  begin
    // if Pos('\', Copy(AppSett.sPathLog, Length(AppSett.sPathLog), 1)) = 0 then
    // sPath := AppSett.sPathLog + '\'
    // else
    // sPath := AppSett.sPathLog;
    sPath := IncludeTrailingPathDelimiter(AppSett.sPathLog);
    WriteToFile(sPath + AppSett.sLogPref + FormatDateTime('yyyymmdd', Now) +
      '.log', sText);
  end;
end;
  // *****************************************************************************
// ������ ������ � ���

  // *****************************************************************************

procedure TMForm.AddToLog(sValue: string; bAddDateTime: Boolean = True; fsStyle:
  TFontStyles = []; Color: Integer = 0);
var
  iDefColor: Integer;
  fsDefStyle: TFontStyles;
begin
  iDefColor := reLog.Font.Color;
  fsDefStyle := reLog.Font.Style;
  reLog.SelAttributes.Style := fsStyle;
  reLog.SelAttributes.Color := Color;
  if bAddDateTime then
    sValue := '[' + DateTimeToStr(Now) + ']: ' + sValue;
  reLog.Lines.Add(sValue);
  reLog.SelAttributes.Style := fsDefStyle;
  reLog.SelAttributes.Color := iDefColor;
  SendMessage(reLog.Handle, WM_VSCROLL, SB_BOTTOM, 0);
  sbBar.Panels.Items[1].Text := IntToStr(reLog.Lines.Count);
  if acWriteLog.Checked then
    WriteLogFile(sValue);
  if AppSett.bShowConsole then
    Writeln(sValue);
end;

procedure TMForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := MessageBox(Application.Handle,
    '�� ������������� ������ ����� �� ���������?', '��������������', MB_YESNO
    or MB_ICONQUESTION) = ID_YES;
end;

procedure TMForm.FormCreate(Sender: TObject);
var
  sAppName: string;
  sVersion: string;
  sParam: string;
begin
  AllocConsole;
    //  SetConsoleTextAttribute(GetStdHandle(STD_OUTPUT_HANDLE), FOREGROUND_BLUE or
  //    FOREGROUND_GREEN or BACKGROUND_RED);
  reLog.PlainText := True;
  // ��������� �������� ������� � ��������� ��� ������������
  sAppName := ParamStr(0);
  sParam := ParamStr(1);
  if not FileExists(sParam) or (Pos('\', sParam) = 0) then
    AppSett.sIniPath := ExtractFilePath(sAppName) + 'dcleaner.ini'
  else
    AppSett.sIniPath := sParam;

  Application.CreateForm(TDM, DM);
  if ReadIniFiles then
  begin
    Application.ShowMainForm := AppSett.bShowWindows;
    Self.Hide;
    // ������ ������ ����� ������ ��������� ������� �����.
    CreateDelTread;
    tmrClear.Enabled := True;
  end;
  acWriteLog.Checked := AppSett.bWriteLog;
  N9.Checked := acWriteLog.Checked;
  sAppName := Application.ExeName;
  sVersion := 'v.' + GetInfo(sAppName);
  AddToLog('������ ��: ' + ExtractFileName(sAppName) + ' ' + sVersion, False, [fsUnderline,
    fsBold]);
  sbBar.Panels.Items[0].Text := sVersion;
  // AddToLog('���������� ��������');
end;

procedure TMForm.FormDestroy(Sender: TObject);
begin
  AddToLog('��������� �����������', True);
  FreeConsole;
end;

procedure TMForm.acAboutExecute(Sender: TObject);
begin
  Application.CreateForm(TAboutF, AboutF);
  AboutF.ShowModal;
end;

procedure TMForm.acExitExecute(Sender: TObject);
begin
  Close;
end;

procedure TMForm.acShowHideExecute(Sender: TObject);
begin
  if Application.ShowMainForm then
  begin
    Application.ShowMainForm := False;
    Self.Hide;
    AddToLog('���� ������');
  end
  else
  begin
    Application.ShowMainForm := True;
    Self.Show;
    AddToLog('���� ��������');
  end;
end;

procedure TMForm.acStopExecute(Sender: TObject);
begin
  bStop := True;
  tmrClear.Enabled := False;
  if not bPause then
  begin
    bPause := True;
    acPauseStart.Caption := '����������';
    acPauseStart.ImageIndex := 1;
    acPauseStart.Hint := '���������� ������';
  end;
  (Sender as TAction).Enabled := False;
  AddToLog('������ ��������� �����������', True, [fsBold]);
end;

procedure TMForm.acWriteLogExecute(Sender: TObject);
begin
  if (Sender as TAction).Checked then
  begin
    AddToLog('������ � ��� �� ����: ���������', True);
    (Sender as TAction).Checked := False;
    AppSett.bWriteLog := False;
    DM.WriteIni(AppSett.sIniPath);
  end
  else
  begin
    AddToLog('������ � ��� �� ����: ��������', True);
    (Sender as TAction).Checked := True;
    AppSett.bWriteLog := True;
    DM.WriteIni(AppSett.sIniPath);
  end;
end;

procedure TMForm.acPauseStartExecute(Sender: TObject);
begin
  acStop.Enabled := True;
  if not bPause then
  begin
    bPause := True;
    tmrClear.Enabled := False;
    (Sender as TAction).Caption := '����������';
    (Sender as TAction).ImageIndex := 1;
    (Sender as TAction).Hint := '���������� ������';
    AddToLog('������ ��������� ��������������', True, [fsBold]);
  end
  else
  begin
    bPause := False;
    tmrClear.Enabled := True;
    (Sender as TAction).Caption := '�����';
    (Sender as TAction).ImageIndex := 0;
    (Sender as TAction).Hint := '������������� ������';
    AddToLog('������ ��������� ����������', True, [fsBold]);
    // ���� ����� ������� ������ ���� �����������
    if bStop then
      CreateDelTread;
    bStop := False;
  end;
end;

procedure TMForm.acReReadSettExecute(Sender: TObject);
begin
  ReadIniFiles;
end;

end.

