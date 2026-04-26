unit UTest.AutoGrow;

interface

procedure RunTests(const ATestNum: Integer);

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  Virtuoso;

procedure Test_ManualGrow();
var
  LBuf: TVirtuoso<Integer>;
  LIndex: Integer;
begin
  Write('  ManualGrow: ');
  LBuf := TVirtuoso<Integer>.Create();
  try
    if not LBuf.Allocate(100) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    for LIndex := 0 to 99 do
      LBuf[LIndex] := LIndex;
    if not LBuf.Grow(1000) then
    begin WriteLn('FAIL - grow returned False'); Exit; end;
    if LBuf.Capacity <> 1000 then
    begin WriteLn('FAIL - capacity <> 1000'); Exit; end;
    for LIndex := 0 to 99 do
    begin
      if LBuf[LIndex] <> LIndex then
      begin WriteLn('FAIL - data lost at ' + IntToStr(LIndex)); Exit; end;
    end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_GrowAlreadyBigEnough();
var
  LBuf: TVirtuoso<Byte>;
begin
  Write('  GrowAlreadyBigEnough: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(1000) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    if not LBuf.Grow(500) then
    begin WriteLn('FAIL - grow returned False'); Exit; end;
    if LBuf.Capacity <> 1000 then
    begin WriteLn('FAIL - capacity changed'); Exit; end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_GrowFileBackedFails();
var
  LBuf: TVirtuoso<Byte>;
  LFile: string;
  LFS: TFileStream;
  LByte: Byte;
begin
  Write('  GrowFileBackedFails: ');
  LFile := TPath.Combine(TPath.GetTempPath(), 'virt_growfail.bin');
  try
    LFS := TFileStream.Create(LFile, fmCreate);
    try
      LByte := 0;
      LFS.WriteBuffer(LByte, 1);
    finally
      LFS.Free();
    end;
    LBuf := TVirtuoso<Byte>.Create();
    try
      LBuf.Open(LFile, vmReadOnly);
      if LBuf.Grow(100) then
      begin WriteLn('FAIL - grow should return False'); Exit; end;
      if LBuf.LastErrorCode <> 'VT12' then
      begin WriteLn('FAIL - expected VT12, got ' + LBuf.LastErrorCode); Exit; end;
      WriteLn('PASS');
    finally
      LBuf.Free();
    end;
  finally
    if TFile.Exists(LFile) then
      TFile.Delete(LFile);
  end;
end;

procedure Test_AutoGrowOnWrite();
var
  LBuf: TVirtuoso<Byte>;
  LData: array[0..99] of Byte;
  LIndex: Integer;
  LCount: UInt64;
begin
  Write('  AutoGrowOnWrite: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(10) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LBuf.AutoGrow := True;
    LBuf.GrowFactor := 2.0;
    for LIndex := 0 to 99 do
      LData[LIndex] := Byte(LIndex);
    LBuf.Position := 0;
    LCount := LBuf.Write(LData, 100);
    if LCount <> 100 then
    begin WriteLn('FAIL - write count <> 100'); Exit; end;
    if LBuf.Capacity < 100 then
    begin WriteLn('FAIL - capacity still < 100'); Exit; end;
    for LIndex := 0 to 99 do
    begin
      if LBuf[LIndex] <> Byte(LIndex) then
      begin WriteLn('FAIL - data mismatch at ' + IntToStr(LIndex)); Exit; end;
    end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_GrowFactor();
var
  LBuf: TVirtuoso<Byte>;
  LData: array[0..199] of Byte;
  LOldCap: UInt64;
begin
  Write('  GrowFactor: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(10) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LBuf.AutoGrow := True;
    LBuf.GrowFactor := 1.5;
    LOldCap := LBuf.Capacity;
    LBuf.Position := 0;
    FillChar(LData, SizeOf(LData), 0);
    LBuf.Write(LData, 200);
    if LBuf.Capacity < Round(LOldCap * 1.5) then
    begin WriteLn('FAIL - capacity not grown enough'); Exit; end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure RunTests(const ATestNum: Integer);
begin
  WriteLn('=== UTest.AutoGrow ===');
  case ATestNum of
    1: Test_ManualGrow();
    2: Test_GrowAlreadyBigEnough();
    3: Test_GrowFileBackedFails();
    4: Test_AutoGrowOnWrite();
    5: Test_GrowFactor();
  else
    Test_ManualGrow();
    Test_GrowAlreadyBigEnough();
    Test_GrowFileBackedFails();
    Test_AutoGrowOnWrite();
    Test_GrowFactor();
  end;
  WriteLn('');
end;

end.
