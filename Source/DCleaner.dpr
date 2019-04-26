program DCleaner;

uses
  Vcl.Forms,
  Windows,
  Dialogs,
  uMain in 'uMain.pas' {MForm},
  Vcl.Themes,
  Vcl.Styles,
  uDataModule in 'uDataModule.pas' {DM: TDataModule},
  uAbout in 'uAbout.pas' {AboutF};

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  TStyleManager.TrySetStyle('Aqua Light Slate');
  Application.Title := 'VMX - DiskCleaner';
  if FindWindow(nil, 'VMX - DiskCleaner') <> 0 then
  begin
    MessageBox(Application.Handle,
      'Программа уже запущена. Запрещён запуск более одной копии программы.',
      'Внимание', MB_OK or MB_ICONWARNING);
    Exit;
  end
  else
  begin
//    TStyleManager.TrySetStyle('Windows10 SlateGray');
    Application.CreateForm(TMForm, MForm);
  Application.Run;
  end;

end.
