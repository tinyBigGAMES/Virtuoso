unit UTest.FileIO;

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
  GTempDir := TPath.Combine(TPath.GetTempPath(), 'VirtuosoTestFileIO');
  if not TDirectory.Exists(GTempDir) then
    TDirectory.CreateDirectory(GTempDir);
end;

procedure CleanupTempDir();
begin
  if TDirectory.Exists(GTempDir) then
    TDirectory.Delete(GTempDir, True);
end;

procedure Test_SaveAndLoad();
var
  LBuf: TVirtuoso<Integer>;
  LLoaded: TVirtuoso<Integer>;
  LFile: string;
  LIndex: Integer;
begin
  Write('  SaveAndLoad: ');
  SetupTempDir();
  try
    LFile := TPath.Combine(GTempDir, 'saveload.bin');
    LBuf := TVirtuoso<Integer>.Create();
    try
      if not LBuf.Allocate(200) then
      begin WriteLn('FAIL - allocate'); Exit; end;
      for LIndex := 0 to 199 do
        LBuf[LIndex] := LIndex * 5;
      LBuf.SaveToFile(LFile);
    finally
      LBuf.Free();
    end;
    LLoaded := TVirtuoso<Integer>.LoadFromFile(LFile);
    try
      if LLoaded.Capacity <> 200 then
      begin WriteLn('FAIL - capacity <> 200'); Exit; end;
      for LIndex := 0 to 199 do
      begin
        if LLoaded[LIndex] <> LIndex * 5 then
        begin WriteLn('FAIL - mismatch at ' + IntToStr(LIndex)); Exit; end;
      end;
      WriteLn('PASS');
    finally
      LLoaded.Free();
    end;
  finally
    CleanupTempDir();
  end;
end;

procedure Test_LoadAlignmentError();
var
  LLoaded: TVirtuoso<Integer>;
  LFile: string;
  LFS: TFileStream;
  LBytes: TBytes;
begin
  Write('  LoadAlignmentError: ');
  SetupTempDir();
  try
    LFile := TPath.Combine(GTempDir, 'unaligned.bin');
    SetLength(LBytes, 7);
    FillChar(LBytes[0], 7, $AA);
    LFS := TFileStream.Create(LFile, fmCreate);
    try
      LFS.WriteBuffer(LBytes[0], 7);
    finally
      LFS.Free();
    end;
    LLoaded := TVirtuoso<Integer>.LoadFromFile(LFile);
    try
      if not LLoaded.HasError() then
      begin WriteLn('FAIL - no error'); Exit; end;
      if LLoaded.LastErrorCode <> 'VT05' then
      begin WriteLn('FAIL - expected VT05, got ' + LLoaded.LastErrorCode); Exit; end;
      WriteLn('PASS');
    finally
      LLoaded.Free();
    end;
  finally
    CleanupTempDir();
  end;
end;

procedure Test_SaveFromReadOnly();
var
  LBuf: TVirtuoso<Byte>;
  LLoaded: TVirtuoso<Byte>;
  LSrcFile: string;
  LDstFile: string;
  LFS: TFileStream;
  LIndex: Integer;
  LByte: Byte;
begin
  Write('  SaveFromReadOnly: ');
  SetupTempDir();
  try
    LSrcFile := TPath.Combine(GTempDir, 'source.bin');
    LDstFile := TPath.Combine(GTempDir, 'copy.bin');
    LFS := TFileStream.Create(LSrcFile, fmCreate);
    try
      for LIndex := 0 to 63 do
      begin
        LByte := Byte(LIndex);
        LFS.WriteBuffer(LByte, 1);
      end;
    finally
      LFS.Free();
    end;
    LBuf := TVirtuoso<Byte>.Create();
    try
      LBuf.Open(LSrcFile, vmReadOnly);
      LBuf.SaveToFile(LDstFile);
    finally
      LBuf.Free();
    end;
    LLoaded := TVirtuoso<Byte>.Create();
    try
      LLoaded.Open(LDstFile, vmReadOnly);
      if LLoaded.Size <> 64 then
      begin WriteLn('FAIL - size mismatch'); Exit; end;
      for LIndex := 0 to 63 do
      begin
        if LLoaded[LIndex] <> Byte(LIndex) then
        begin WriteLn('FAIL - data mismatch at ' + IntToStr(LIndex)); Exit; end;
      end;
      WriteLn('PASS');
    finally
      LLoaded.Free();
    end;
  finally
    CleanupTempDir();
  end;
end;

procedure Test_SaveOverwrite();
var
  LBuf: TVirtuoso<Byte>;
  LLoaded: TVirtuoso<Byte>;
  LFile: string;
begin
  Write('  SaveOverwrite: ');
  SetupTempDir();
  try
    LFile := TPath.Combine(GTempDir, 'overwrite.bin');
    LBuf := TVirtuoso<Byte>.Create();
    try
      LBuf.Allocate(10);
      LBuf.Fill(11);
      LBuf.SaveToFile(LFile);
    finally
      LBuf.Free();
    end;
    LBuf := TVirtuoso<Byte>.Create();
    try
      LBuf.Allocate(20);
      LBuf.Fill(22);
      LBuf.SaveToFile(LFile);
    finally
      LBuf.Free();
    end;
    LLoaded := TVirtuoso<Byte>.Create();
    try
      LLoaded.Open(LFile, vmReadOnly);
      if LLoaded.Size <> 20 then
      begin WriteLn('FAIL - size <> 20'); Exit; end;
      if LLoaded[0] <> 22 then
      begin WriteLn('FAIL - data not from second save'); Exit; end;
      WriteLn('PASS');
    finally
      LLoaded.Free();
    end;
  finally
    CleanupTempDir();
  end;
end;

procedure RunTests(const ATestNum: Integer);
begin
  WriteLn('=== UTest.FileIO ===');
  case ATestNum of
    1: Test_SaveAndLoad();
    2: Test_LoadAlignmentError();
    3: Test_SaveFromReadOnly();
    4: Test_SaveOverwrite();
  else
    Test_SaveAndLoad();
    Test_LoadAlignmentError();
    Test_SaveFromReadOnly();
    Test_SaveOverwrite();
  end;
  WriteLn('');
end;

end.
