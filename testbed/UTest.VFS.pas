unit UTest.VFS;

interface

procedure RunTests(const ATestNum: Integer);

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  Virtuoso,
  Virtuoso.VFS;

var
  GTempDir: string;
  GArchiveFile: string;

procedure SetupTestData();
var
  LPath: string;
  LFS: TFileStream;
  LBytes: TBytes;
  LIndex: Integer;
begin
  GTempDir := TPath.Combine(TPath.GetTempPath(), 'VirtuosoTestVFS');
  GArchiveFile := TPath.Combine(TPath.GetTempPath(), 'VirtuosoTestVFS_out.vpk');
  if TDirectory.Exists(GTempDir) then
    TDirectory.Delete(GTempDir, True);
  TDirectory.CreateDirectory(GTempDir);
  TFile.WriteAllText(TPath.Combine(GTempDir, 'readme.txt'), 'Hello Virtuoso VFS!');
  TFile.WriteAllText(TPath.Combine(GTempDir, 'config.json'), '{"version":1}');
  LPath := TPath.Combine(GTempDir, 'textures');
  TDirectory.CreateDirectory(LPath);
  SetLength(LBytes, 128);
  for LIndex := 0 to 127 do
    LBytes[LIndex] := Byte(LIndex);
  LFS := TFileStream.Create(TPath.Combine(LPath, 'sky.png'), fmCreate);
  try
    LFS.WriteBuffer(LBytes[0], Length(LBytes));
  finally
    LFS.Free();
  end;
  SetLength(LBytes, 64);
  for LIndex := 0 to 63 do
    LBytes[LIndex] := Byte(255 - LIndex);
  LFS := TFileStream.Create(TPath.Combine(LPath, 'ground.png'), fmCreate);
  try
    LFS.WriteBuffer(LBytes[0], Length(LBytes));
  finally
    LFS.Free();
  end;
  LPath := TPath.Combine(GTempDir, 'sounds');
  TDirectory.CreateDirectory(LPath);
  LPath := TPath.Combine(LPath, 'music');
  TDirectory.CreateDirectory(LPath);
  TFile.WriteAllText(TPath.Combine(LPath, 'theme.ogg'), 'fake-ogg-data-12345');
  LPath := TPath.Combine(GTempDir, 'sounds' + TPath.DirectorySeparatorChar + 'sfx');
  TDirectory.CreateDirectory(LPath);
  TFile.WriteAllText(TPath.Combine(LPath, 'click.wav'), 'fake-wav-click');
end;

procedure CleanupTestData();
begin
  if TDirectory.Exists(GTempDir) then
    TDirectory.Delete(GTempDir, True);
  if TFile.Exists(GArchiveFile) then
    TFile.Delete(GArchiveFile);
end;

function PackTestData(): Boolean;
begin
  Result := TVirtuosoVFS.PackDirectory(GTempDir, GArchiveFile,
    procedure(const AInfo: TVFSPackInfo; var ACancel: Boolean; const AUserData: Pointer)
    begin
      case AInfo.Status of
        vpsStarting:
          WriteLn(Format('    [PACK] Starting (%d files)', [AInfo.FileCount]));
        vpsFileBegin:
          WriteLn(Format('    [PACK] %d/%d %s', [AInfo.FileIndex, AInfo.FileCount, AInfo.EntryPath]));
        vpsCompleted:
          WriteLn(Format('    [PACK] Completed (%d bytes)', [AInfo.TotalBytes]));
        vpsError:
          WriteLn(Format('    [PACK] ERROR: %s', [AInfo.ErrorMessage]));
      end;
    end
  );
end;

procedure Test_PackAndOpen();
var
  LVFS: TVirtuosoVFS;
begin
  Write('  PackAndOpen: ');
  SetupTestData();
  try
    if not PackTestData() then
    begin WriteLn('FAIL - pack'); Exit; end;
    LVFS := TVirtuosoVFS.Create();
    try
      if not LVFS.Open(GArchiveFile) then
      begin WriteLn('FAIL - open'); Exit; end;
      if not LVFS.IsOpen() then
      begin WriteLn('FAIL - not open'); Exit; end;
      if LVFS.EntryCount() <> 6 then
      begin WriteLn('FAIL - entry count <> 6, got ' + IntToStr(LVFS.EntryCount())); Exit; end;
      WriteLn('PASS');
    finally
      LVFS.Free();
    end;
  finally
    CleanupTestData();
  end;
end;

procedure Test_PackCallback();
var
  LStartCount: Integer;
  LFileBeginCount: Integer;
  LFileEndCount: Integer;
  LCompletedCount: Integer;
begin
  Write('  PackCallback: ');
  SetupTestData();
  try
    LStartCount := 0;
    LFileBeginCount := 0;
    LFileEndCount := 0;
    LCompletedCount := 0;
    TVirtuosoVFS.PackDirectory(GTempDir, GArchiveFile,
      procedure(const AInfo: TVFSPackInfo; var ACancel: Boolean; const AUserData: Pointer)
      begin
        case AInfo.Status of
          vpsStarting:  Inc(LStartCount);
          vpsFileBegin: Inc(LFileBeginCount);
          vpsFileEnd:   Inc(LFileEndCount);
          vpsCompleted: Inc(LCompletedCount);
        end;
      end
    );
    if LStartCount <> 1 then
    begin WriteLn('FAIL - start count <> 1'); Exit; end;
    if LFileBeginCount <> 6 then
    begin WriteLn('FAIL - file begin <> 6, got ' + IntToStr(LFileBeginCount)); Exit; end;
    if LFileEndCount <> 6 then
    begin WriteLn('FAIL - file end <> 6'); Exit; end;
    if LCompletedCount <> 1 then
    begin WriteLn('FAIL - completed <> 1'); Exit; end;
    WriteLn('PASS');
  finally
    CleanupTestData();
  end;
end;

procedure Test_PackCancel();
var
  LResult: Boolean;
begin
  Write('  PackCancel: ');
  SetupTestData();
  try
    LResult := TVirtuosoVFS.PackDirectory(GTempDir, GArchiveFile,
      procedure(const AInfo: TVFSPackInfo; var ACancel: Boolean; const AUserData: Pointer)
      begin
        if (AInfo.Status = vpsFileBegin) and (AInfo.FileIndex = 2) then
          ACancel := True;
      end
    );
    if LResult then
    begin WriteLn('FAIL - should return False'); Exit; end;
    WriteLn('PASS');
  finally
    CleanupTestData();
  end;
end;

procedure Test_PackEmptyDir();
var
  LEmptyDir: string;
  LResult: Boolean;
begin
  Write('  PackEmptyDir: ');
  LEmptyDir := TPath.Combine(TPath.GetTempPath(), 'VirtuosoTestEmpty');
  try
    if TDirectory.Exists(LEmptyDir) then
      TDirectory.Delete(LEmptyDir, True);
    TDirectory.CreateDirectory(LEmptyDir);
    LResult := TVirtuosoVFS.PackDirectory(LEmptyDir, GArchiveFile);
    if LResult then
    begin WriteLn('FAIL - should return False'); Exit; end;
    WriteLn('PASS');
  finally
    if TDirectory.Exists(LEmptyDir) then
      TDirectory.Delete(LEmptyDir, True);
  end;
end;

procedure Test_PackNonExistentDir();
var
  LResult: Boolean;
begin
  Write('  PackNonExistentDir: ');
  LResult := TVirtuosoVFS.PackDirectory('C:\__no_such_dir_12345__', GArchiveFile);
  if LResult then
  begin WriteLn('FAIL - should return False'); Exit; end;
  WriteLn('PASS');
end;

procedure Test_FileExists();
var
  LVFS: TVirtuosoVFS;
begin
  Write('  FileExists: ');
  SetupTestData();
  try
    PackTestData();
    LVFS := TVirtuosoVFS.Create();
    try
      LVFS.Open(GArchiveFile);
      if not LVFS.FileExists('readme.txt') then
      begin WriteLn('FAIL - readme.txt not found'); Exit; end;
      if not LVFS.FileExists('textures/sky.png') then
      begin WriteLn('FAIL - textures/sky.png not found'); Exit; end;
      if LVFS.FileExists('nonexistent.dat') then
      begin WriteLn('FAIL - ghost file found'); Exit; end;
      WriteLn('PASS');
    finally
      LVFS.Free();
    end;
  finally
    CleanupTestData();
  end;
end;

procedure Test_OpenFile();
var
  LVFS: TVirtuosoVFS;
  LView: TVirtuosoView<Byte>;
  LOriginal: TBytes;
  LIndex: Integer;
begin
  Write('  OpenFile: ');
  SetupTestData();
  try
    PackTestData();
    LVFS := TVirtuosoVFS.Create();
    try
      LVFS.Open(GArchiveFile);
      LOriginal := TEncoding.Default.GetBytes('Hello Virtuoso VFS!');
      LView := LVFS.OpenFile('readme.txt');
      try
        if LView.Size <> UInt64(Length(LOriginal)) then
        begin WriteLn('FAIL - size mismatch'); Exit; end;
        for LIndex := 0 to Length(LOriginal) - 1 do
        begin
          if LView[LIndex] <> LOriginal[LIndex] then
          begin WriteLn('FAIL - byte mismatch at ' + IntToStr(LIndex)); Exit; end;
        end;
      finally
        LView.Free();
      end;
      LView := LVFS.OpenFile('textures/sky.png');
      try
        if LView.Size <> 128 then
        begin WriteLn('FAIL - sky.png size <> 128'); Exit; end;
        if LView[0] <> 0 then
        begin WriteLn('FAIL - sky.png[0] <> 0'); Exit; end;
        if LView[127] <> 127 then
        begin WriteLn('FAIL - sky.png[127] <> 127'); Exit; end;
      finally
        LView.Free();
      end;
      WriteLn('PASS');
    finally
      LVFS.Free();
    end;
  finally
    CleanupTestData();
  end;
end;

procedure Test_FileSize();
var
  LVFS: TVirtuosoVFS;
begin
  Write('  FileSize: ');
  SetupTestData();
  try
    PackTestData();
    LVFS := TVirtuosoVFS.Create();
    try
      LVFS.Open(GArchiveFile);
      if LVFS.FileSize('textures/sky.png') <> 128 then
      begin WriteLn('FAIL - sky.png size'); Exit; end;
      if LVFS.FileSize('textures/ground.png') <> 64 then
      begin WriteLn('FAIL - ground.png size'); Exit; end;
      WriteLn('PASS');
    finally
      LVFS.Free();
    end;
  finally
    CleanupTestData();
  end;
end;

procedure Test_ListFilesAll();
var
  LVFS: TVirtuosoVFS;
  LFiles: TArray<string>;
begin
  Write('  ListFilesAll: ');
  SetupTestData();
  try
    PackTestData();
    LVFS := TVirtuosoVFS.Create();
    try
      LVFS.Open(GArchiveFile);
      LFiles := LVFS.ListFiles();
      if Length(LFiles) <> 6 then
      begin WriteLn('FAIL - count <> 6, got ' + IntToStr(Length(LFiles))); Exit; end;
      WriteLn('PASS');
    finally
      LVFS.Free();
    end;
  finally
    CleanupTestData();
  end;
end;

procedure Test_ListFilesByDir();
var
  LVFS: TVirtuosoVFS;
  LFiles: TArray<string>;
begin
  Write('  ListFilesByDir: ');
  SetupTestData();
  try
    PackTestData();
    LVFS := TVirtuosoVFS.Create();
    try
      LVFS.Open(GArchiveFile);
      LFiles := LVFS.ListFiles('textures');
      if Length(LFiles) <> 2 then
      begin WriteLn('FAIL - textures count <> 2'); Exit; end;
      LFiles := LVFS.ListFiles('sounds');
      if Length(LFiles) <> 2 then
      begin WriteLn('FAIL - sounds count <> 2'); Exit; end;
      WriteLn('PASS');
    finally
      LVFS.Free();
    end;
  finally
    CleanupTestData();
  end;
end;

procedure Test_PathCaseInsensitive();
var
  LVFS: TVirtuosoVFS;
begin
  Write('  PathCaseInsensitive: ');
  SetupTestData();
  try
    PackTestData();
    LVFS := TVirtuosoVFS.Create();
    try
      LVFS.Open(GArchiveFile);
      if not LVFS.FileExists('textures/sky.png') then
      begin WriteLn('FAIL - lowercase'); Exit; end;
      if not LVFS.FileExists('TEXTURES/SKY.PNG') then
      begin WriteLn('FAIL - uppercase'); Exit; end;
      if not LVFS.FileExists('Textures\Sky.PNG') then
      begin WriteLn('FAIL - backslash mixed case'); Exit; end;
      WriteLn('PASS');
    finally
      LVFS.Free();
    end;
  finally
    CleanupTestData();
  end;
end;

procedure Test_Subdirectories();
var
  LVFS: TVirtuosoVFS;
  LView: TVirtuosoView<Byte>;
begin
  Write('  Subdirectories: ');
  SetupTestData();
  try
    PackTestData();
    LVFS := TVirtuosoVFS.Create();
    try
      LVFS.Open(GArchiveFile);
      if not LVFS.FileExists('sounds/music/theme.ogg') then
      begin WriteLn('FAIL - deep path not found'); Exit; end;
      LView := LVFS.OpenFile('sounds/music/theme.ogg');
      try
        if LView.Size = 0 then
        begin WriteLn('FAIL - empty view'); Exit; end;
      finally
        LView.Free();
      end;
      if not LVFS.FileExists('sounds/sfx/click.wav') then
      begin WriteLn('FAIL - sfx path not found'); Exit; end;
      WriteLn('PASS');
    finally
      LVFS.Free();
    end;
  finally
    CleanupTestData();
  end;
end;

procedure Test_ForcedExtension();
var
  LVFS: TVirtuosoVFS;
begin
  Write('  ForcedExtension: ');
  SetupTestData();
  try
    PackTestData();
    LVFS := TVirtuosoVFS.Create();
    try
      if not LVFS.Open(TPath.ChangeExtension(GArchiveFile, '')) then
      begin WriteLn('FAIL - open without ext'); Exit; end;
      LVFS.Close();
      if not LVFS.Open(TPath.ChangeExtension(GArchiveFile, '.dat')) then
      begin WriteLn('FAIL - open with .dat'); Exit; end;
      LVFS.Close();
      if not LVFS.Open(GArchiveFile) then
      begin WriteLn('FAIL - open with .vpk'); Exit; end;
      WriteLn('PASS');
    finally
      LVFS.Free();
    end;
  finally
    CleanupTestData();
  end;
end;

procedure Test_OpenInvalidFile();
var
  LVFS: TVirtuosoVFS;
  LFile: string;
  LFS: TFileStream;
  LBytes: TBytes;
begin
  Write('  OpenInvalidFile: ');
  LFile := TPath.Combine(TPath.GetTempPath(), 'garbage.vpk');
  try
    SetLength(LBytes, 64);
    FillChar(LBytes[0], 64, $FF);
    LFS := TFileStream.Create(LFile, fmCreate);
    try
      LFS.WriteBuffer(LBytes[0], 64);
    finally
      LFS.Free();
    end;
    LVFS := TVirtuosoVFS.Create();
    try
      if LVFS.Open(LFile) then
      begin WriteLn('FAIL - should return False'); Exit; end;
      WriteLn('PASS');
    finally
      LVFS.Free();
    end;
  finally
    if TFile.Exists(LFile) then
      TFile.Delete(LFile);
  end;
end;

procedure Test_OpenFileMissing();
var
  LVFS: TVirtuosoVFS;
  LView: TVirtuosoView<Byte>;
  LRaised: Boolean;
begin
  Write('  OpenFileMissing: ');
  SetupTestData();
  try
    PackTestData();
    LVFS := TVirtuosoVFS.Create();
    try
      LVFS.Open(GArchiveFile);
      LRaised := False;
      try
        LView := LVFS.OpenFile('no_such_file.xyz');
        LView.Free();
      except
        on E: EFileNotFoundException do
          LRaised := True;
      end;
      if not LRaised then
      begin WriteLn('FAIL - no exception'); Exit; end;
      WriteLn('PASS');
    finally
      LVFS.Free();
    end;
  finally
    CleanupTestData();
  end;
end;

procedure RunTests(const ATestNum: Integer);
begin
  WriteLn('=== UTest.VFS ===');
  case ATestNum of
     1: Test_PackAndOpen();
     2: Test_PackCallback();
     3: Test_PackCancel();
     4: Test_PackEmptyDir();
     5: Test_PackNonExistentDir();
     6: Test_FileExists();
     7: Test_OpenFile();
     8: Test_FileSize();
     9: Test_ListFilesAll();
    10: Test_ListFilesByDir();
    11: Test_PathCaseInsensitive();
    12: Test_Subdirectories();
    13: Test_ForcedExtension();
    14: Test_OpenInvalidFile();
    15: Test_OpenFileMissing();
  else
    Test_PackAndOpen();
    Test_PackCallback();
    Test_PackCancel();
    Test_PackEmptyDir();
    Test_PackNonExistentDir();
    Test_FileExists();
    Test_OpenFile();
    Test_FileSize();
    Test_ListFilesAll();
    Test_ListFilesByDir();
    Test_PathCaseInsensitive();
    Test_Subdirectories();
    Test_ForcedExtension();
    Test_OpenInvalidFile();
    Test_OpenFileMissing();
  end;
  WriteLn('');
end;

end.
