unit UTest.FileMapping;

interface

procedure RunTests(const ATestNum: Integer);

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  Virtuoso;

var
  GTempDir: string;

procedure SetupTempDir();
begin
  GTempDir := TPath.Combine(TPath.GetTempPath(), 'VirtuosoTestFileMap');
  if not TDirectory.Exists(GTempDir) then
    TDirectory.CreateDirectory(GTempDir);
end;

procedure CleanupTempDir();
begin
  if TDirectory.Exists(GTempDir) then
    TDirectory.Delete(GTempDir, True);
end;

function CreateTempFile(const AName: string; const ASize: Integer): string;
var
  LStream: TFileStream;
  LIndex: Integer;
  LByte: Byte;
begin
  Result := TPath.Combine(GTempDir, AName);
  LStream := TFileStream.Create(Result, fmCreate);
  try
    for LIndex := 0 to ASize - 1 do
    begin
      LByte := Byte(LIndex mod 256);
      LStream.WriteBuffer(LByte, 1);
    end;
  finally
    LStream.Free();
  end;
end;

procedure Test_OpenReadOnly();
var
  LBuf: TVirtuoso<Byte>;
  LFile: string;
  LIndex: Integer;
begin
  Write('  OpenReadOnly: ');
  SetupTempDir();
  try
    LFile := CreateTempFile('readonly.bin', 256);
    LBuf := TVirtuoso<Byte>.Create();
    try
      if not LBuf.Open(LFile, vmReadOnly) then
      begin WriteLn('FAIL - open'); Exit; end;
      if not LBuf.IsOpen then
      begin WriteLn('FAIL - not open'); Exit; end;
      if not LBuf.IsReadOnly then
      begin WriteLn('FAIL - not readonly'); Exit; end;
      if LBuf.Size <> 256 then
      begin WriteLn('FAIL - size <> 256'); Exit; end;
      for LIndex := 0 to 255 do
      begin
        if LBuf[LIndex] <> Byte(LIndex mod 256) then
        begin WriteLn('FAIL - data mismatch at ' + IntToStr(LIndex)); Exit; end;
      end;
      WriteLn('PASS');
    finally
      LBuf.Free();
    end;
  finally
    CleanupTempDir();
  end;
end;

procedure Test_ReadOnlyWriteRaises();
var
  LBuf: TVirtuoso<Byte>;
  LFile: string;
  LRaised: Boolean;
begin
  Write('  ReadOnlyWriteRaises: ');
  SetupTempDir();
  try
    LFile := CreateTempFile('rowrite.bin', 64);
    LBuf := TVirtuoso<Byte>.Create();
    try
      LBuf.Open(LFile, vmReadOnly);
      LRaised := False;
      try
        LBuf[0] := 99;
      except
        on E: EInvalidOperation do
          LRaised := True;
      end;
      if not LRaised then
      begin WriteLn('FAIL - no exception on write'); Exit; end;
      WriteLn('PASS');
    finally
      LBuf.Free();
    end;
  finally
    CleanupTempDir();
  end;
end;

procedure Test_OpenReadWrite();
var
  LBuf: TVirtuoso<Byte>;
  LFile: string;
begin
  Write('  OpenReadWrite: ');
  SetupTempDir();
  try
    LFile := CreateTempFile('readwrite.bin', 128);
    LBuf := TVirtuoso<Byte>.Create();
    try
      if not LBuf.Open(LFile, vmReadWrite) then
      begin WriteLn('FAIL - open rw'); Exit; end;
      LBuf[0] := 222;
      LBuf[127] := 111;
      LBuf.FlushToDisk();
    finally
      LBuf.Free();
    end;
    LBuf := TVirtuoso<Byte>.Create();
    try
      if not LBuf.Open(LFile, vmReadOnly) then
      begin WriteLn('FAIL - reopen'); Exit; end;
      if (LBuf[0] <> 222) or (LBuf[127] <> 111) then
      begin WriteLn('FAIL - changes not persisted'); Exit; end;
      WriteLn('PASS');
    finally
      LBuf.Free();
    end;
  finally
    CleanupTempDir();
  end;
end;

procedure Test_OpenCopyOnWrite();
var
  LBuf: TVirtuoso<Byte>;
  LFile: string;
begin
  Write('  OpenCopyOnWrite: ');
  SetupTempDir();
  try
    LFile := CreateTempFile('cow.bin', 64);
    LBuf := TVirtuoso<Byte>.Create();
    try
      if not LBuf.Open(LFile, vmCopyOnWrite) then
      begin WriteLn('FAIL - open cow'); Exit; end;
      LBuf[0] := 255;
    finally
      LBuf.Free();
    end;
    LBuf := TVirtuoso<Byte>.Create();
    try
      LBuf.Open(LFile, vmReadOnly);
      if LBuf[0] <> 0 then
      begin WriteLn('FAIL - original changed'); Exit; end;
      WriteLn('PASS');
    finally
      LBuf.Free();
    end;
  finally
    CleanupTempDir();
  end;
end;

procedure Test_OpenNonExistent();
var
  LBuf: TVirtuoso<Byte>;
begin
  Write('  OpenNonExistent: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if LBuf.Open('C:\__nonexistent_file_12345.bin', vmReadOnly) then
    begin WriteLn('FAIL - should return False'); Exit; end;
    if not LBuf.HasError() then
    begin WriteLn('FAIL - no error'); Exit; end;
    if LBuf.LastErrorCode <> 'VT07' then
    begin WriteLn('FAIL - expected VT07, got ' + LBuf.LastErrorCode); Exit; end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_OpenEmptyFile();
var
  LBuf: TVirtuoso<Byte>;
  LFile: string;
begin
  Write('  OpenEmptyFile: ');
  SetupTempDir();
  try
    LFile := CreateTempFile('empty.bin', 0);
    LBuf := TVirtuoso<Byte>.Create();
    try
      if LBuf.Open(LFile, vmReadOnly) then
      begin WriteLn('FAIL - should return False'); Exit; end;
      if LBuf.LastErrorCode <> 'VT11' then
      begin WriteLn('FAIL - expected VT11, got ' + LBuf.LastErrorCode); Exit; end;
      WriteLn('PASS');
    finally
      LBuf.Free();
    end;
  finally
    CleanupTempDir();
  end;
end;

procedure Test_FlushToDisk();
var
  LBuf: TVirtuoso<Byte>;
  LFile: string;
begin
  Write('  FlushToDisk: ');
  SetupTempDir();
  try
    LFile := CreateTempFile('flush.bin', 64);
    LBuf := TVirtuoso<Byte>.Create();
    try
      LBuf.Open(LFile, vmReadWrite);
      LBuf[0] := 77;
      if not LBuf.FlushToDisk() then
      begin WriteLn('FAIL - flush rw returned False'); Exit; end;
    finally
      LBuf.Free();
    end;
    LBuf := TVirtuoso<Byte>.Create();
    try
      LBuf.Open(LFile, vmReadOnly);
      if not LBuf.FlushToDisk() then
      begin WriteLn('FAIL - flush ro returned False'); Exit; end;
      WriteLn('PASS');
    finally
      LBuf.Free();
    end;
  finally
    CleanupTempDir();
  end;
end;

procedure RunTests(const ATestNum: Integer);
begin
  WriteLn('=== UTest.FileMapping ===');
  case ATestNum of
    1: Test_OpenReadOnly();
    2: Test_ReadOnlyWriteRaises();
    3: Test_OpenReadWrite();
    4: Test_OpenCopyOnWrite();
    5: Test_OpenNonExistent();
    6: Test_OpenEmptyFile();
    7: Test_FlushToDisk();
  else
    Test_OpenReadOnly();
    Test_ReadOnlyWriteRaises();
    Test_OpenReadWrite();
    Test_OpenCopyOnWrite();
    Test_OpenNonExistent();
    Test_OpenEmptyFile();
    Test_FlushToDisk();
  end;
  WriteLn('');
end;

end.
