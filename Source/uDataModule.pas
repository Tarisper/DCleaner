unit uDataModule;

interface

uses
  System.SysUtils, System.Classes, IniFiles, Forms, uMain, Winapi.Windows,
  VCL.Graphics;

type
  TDM = class(TDataModule)
  private
    { Private declarations }
    procedure Write(sPath: string);
  public
    { Public declarations }
    function ReadIni(const sPath: string): Boolean;
    procedure WriteIni(sPath: string);
    // procedure WriteIni;
  end;

var
  DM: TDM;

implementation

{%CLASSGROUP 'Vcl.Controls.TControl'}
{$R *.dfm}

procedure TDM.Write(sPath: string);
var
  ini: TMemIniFile;
begin
  ini := TMemIniFile.Create(AppSett.sIniPath);
  try
    with ini, AppSett, FilesSett do
    begin
      // WriteBool('Ver', 'bTest', False);
      WriteBool('Application', 'bShowWindows', bShowWindows);
      WriteBool('Application', 'bWriteLog', bWriteLog);
      WriteString('Application', 'sPathLog', sPathLog);
      WriteString('Application', 'sLogPref', sLogPref);
      WriteInteger('Application', 'iStartInterval', iStartInterval);
      WriteInteger('Application', 'iDelInterval', iDelInterval);
      UpdateFile;
    end;
  finally
    ini.Free;
  end;
end;

procedure TDM.WriteIni(sPath: string);
begin
  if FileExists(sPath) then
    Write(sPath);
end;

function TDM.ReadIni(const sPath: string): Boolean;
var
  iNum: Integer;
  sValue: string;
  ini: TMemIniFile;
begin
  Result := False;
  try
    if FileExists(AppSett.sIniPath) then
    begin
      ini := TMemIniFile.Create(AppSett.sIniPath);
      with ini, AppSett, FilesSett do
      begin
        bShowWindows := MForm.IntToBool(ReadInteger('Application',
          'bShowWindows', 1));
        bWriteLog := MForm.IntToBool(ReadInteger('Application', 'bWriteLog', 1));
        sPathLog := ReadString('Application', 'sPathLog', sPath);
        try
          if not DirectoryExists(sPathLog) then
            if ForceDirectories(sPathLog) then
              bLogExist := True
            else
            begin
              MForm.AddToLog('Ошибка в параметре sPathLog. Невозможно создать директорию c именем "'
                + sPathLog + '". Лог на диск не записан', True, [fsBold], clRed);
              bLogExist := False;
            end;
        except
          on E: Exception do
            MForm.AddToLog(E.Message + ':' + #13#10 +
              'Ошибка в параметре sPathLog. Невозможно создать директорию c именем "'
              + sPathLog + '". Лог на диск не записан', True, [fsBold], clRed);
        end;
        sLogPref := ReadString('Application', 'sLogPref', DEF_PREF);
        iStartInterval := ReadInteger('Application', 'iStartInterval', MAX_AGE);
        iDelInterval := ReadInteger('Application', 'iDelInterval', DEL_INTERVAL);
        bShowConsole := ReadBool('Application', 'bShowConsole', True);
        if Values = nil then
          Values := TStringList.Create
        else
          Values.Clear;
        ReadSection('Files', Values);
        SetLength(Settings, Values.Count);
        if High(Settings) >= 0 then
        begin
          for iNum := Low(Settings) to High(Settings) do
          begin
            sValue := ReadString('Files', Values.Strings[iNum], '');
            Settings[iNum].Name := Copy(sValue, 0, Pos('*', sValue) - 1);
            sValue := Copy(sValue, Pos('*', sValue), Length(sValue));
            Settings[iNum].Filter := Trim(Copy(sValue, 0, Pos(',', sValue) - 1));
            sValue := Trim(Copy(sValue, Pos(',', sValue) + 1, Length(sValue)));
            try
              Settings[iNum].Age := StrToInt(Copy(sValue, 0, Length(sValue)));
            except
            end;
            if Settings[iNum].Age = 0 then
              Settings[iNum].Age := MAX_AGE;
          end;
          Result := True;
          Values.Clear;
        end;
      end;
    end;
  finally
    if not FileExists(AppSett.sIniPath) then
    begin
      if Assigned(ini) then
        ini.Free;
      Write(sPath);
    end;
  end;
end;

end.

