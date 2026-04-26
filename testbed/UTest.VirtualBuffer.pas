unit UTest.VirtualBuffer;

interface

procedure RunTests(const ATestNum: Integer);

implementation

uses
  System.SysUtils,
  Virtuoso;

type
  TTestRecord = packed record
    X: Single;
    Y: Single;
    Z: Single;
    ID: Integer;
  end;

procedure Test_AllocateBasic();
var
  LBuf: TVirtuoso<Byte>;
begin
  Write('  AllocateBasic: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    // Small
    if not LBuf.Allocate(1) then
    begin
      WriteLn('FAIL - allocate 1');
      Exit;
    end;

    if (not LBuf.IsOpen) or (LBuf.Capacity <> 1) or
      (LBuf.MappingMode <> vmAllocate) then
    begin
      WriteLn('FAIL - state after allocate 1');
      Exit;
    end;

    LBuf.Close();

    // Medium
    if not LBuf.Allocate(1000) then
    begin
      WriteLn('FAIL - allocate 1000');
      Exit;
    end;

    if LBuf.Capacity <> 1000 then
    begin
      WriteLn('FAIL - capacity 1000');
      Exit;
    end;

    LBuf.Close();

    // Large (1M)
    if not LBuf.Allocate(1024 * 1024) then
    begin
      WriteLn('FAIL - allocate 1M');
      Exit;
    end;

    if LBuf.Capacity <> 1024 * 1024 then
    begin
      WriteLn('FAIL - capacity 1M');
      Exit;
    end;

    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_AllocateZero();
var
  LBuf: TVirtuoso<Byte>;
begin
  Write('  AllocateZero: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if LBuf.Allocate(0) then
    begin
      WriteLn('FAIL - should return False');
      Exit;
    end;

    if not LBuf.HasError() then
    begin
      WriteLn('FAIL - no error set');
      Exit;
    end;

    if LBuf.LastErrorCode <> 'VT01' then
    begin
      WriteLn('FAIL - expected VT01, got ' + LBuf.LastErrorCode);
      Exit;
    end;

    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_TypedAccess();
var
  LIntBuf: TVirtuoso<Integer>;
  LRecBuf: TVirtuoso<TTestRecord>;
  LIndex: Integer;
  LRec: TTestRecord;
begin
  Write('  TypedAccess: ');
  LIntBuf := TVirtuoso<Integer>.Create();
  try
    if not LIntBuf.Allocate(100) then
    begin
      WriteLn('FAIL - allocate int');
      Exit;
    end;

    for LIndex := 0 to 99 do
      LIntBuf[LIndex] := LIndex * 7;
    for LIndex := 0 to 99 do
    begin
      if LIntBuf[LIndex] <> LIndex * 7 then
      begin
        WriteLn('FAIL - int mismatch at ' + IntToStr(LIndex));
        Exit;
      end;
    end;

  finally
    LIntBuf.Free();
  end;

  LRecBuf := TVirtuoso<TTestRecord>.Create();
  try
    if not LRecBuf.Allocate(50) then
    begin
      WriteLn('FAIL - allocate rec');
      Exit;
    end;

    for LIndex := 0 to 49 do
    begin
      LRec.X := LIndex * 1.0;
      LRec.Y := LIndex * 2.0;
      LRec.Z := LIndex * 3.0;
      LRec.ID := LIndex;
      LRecBuf[LIndex] := LRec;
    end;

    for LIndex := 0 to 49 do
    begin
      LRec := LRecBuf[LIndex];
      if (LRec.ID <> LIndex) or (Round(LRec.X) <> LIndex) then
      begin
        WriteLn('FAIL - rec mismatch at ' + IntToStr(LIndex));
        Exit;
      end;
    end;

    WriteLn('PASS');
  finally
    LRecBuf.Free();
  end;
end;

procedure Test_FillAndSearch();
var
  LBuf: TVirtuoso<Integer>;
begin
  Write('  FillAndSearch: ');
  LBuf := TVirtuoso<Integer>.Create();
  try
    if not LBuf.Allocate(500) then
    begin
      WriteLn('FAIL - allocate');
      Exit;
    end;

    LBuf.Fill(42);
    if not LBuf.Contains(42) then
    begin
      WriteLn('FAIL - Contains after Fill');
      Exit;
    end;

    if LBuf.IndexOf(42) <> 0 then
    begin
      WriteLn('FAIL - IndexOf should be 0');
      Exit;
    end;

    LBuf[250] := 999;
    if LBuf.IndexOf(999) <> 250 then
    begin
      WriteLn('FAIL - IndexOf 999 <> 250');
      Exit;
    end;

    if LBuf.IndexOf(-1) <> -1 then
    begin
      WriteLn('FAIL - missing value should return -1');
      Exit;
    end;

    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_ZeroMemory();
var
  LBuf: TVirtuoso<Integer>;
  LIndex: Integer;
begin
  Write('  ZeroMemory: ');
  LBuf := TVirtuoso<Integer>.Create();
  try
    if not LBuf.Allocate(100) then
    begin
      WriteLn('FAIL - allocate');
      Exit;
    end;

    LBuf.Fill(Integer($DEADBEEF));
    LBuf.ZeroMemory();

    for LIndex := 0 to 99 do
    begin
      if LBuf[LIndex] <> 0 then
      begin
        WriteLn('FAIL - non-zero at ' + IntToStr(LIndex));
        Exit;
      end;
    end;

    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_CopyFrom();
var
  LBuf: TVirtuoso<Byte>;
  LSource: TBytes;
  LIndex: Integer;
begin
  Write('  CopyFrom: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(256) then
    begin
      WriteLn('FAIL - allocate');
      Exit;
    end;

    SetLength(LSource, 256);
    for LIndex := 0 to 255 do
      LSource[LIndex] := Byte(LIndex);

    LBuf.CopyFrom(@LSource[0], 256);
    for LIndex := 0 to 255 do
    begin
      if LBuf[LIndex] <> Byte(LIndex) then
      begin
        WriteLn('FAIL - mismatch at ' + IntToStr(LIndex));
        Exit;
      end;
    end;

    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_ReallocMultiple();
var
  LBuf: TVirtuoso<Byte>;
begin
  Write('  ReallocMultiple: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(100) then
    begin
      WriteLn('FAIL - first allocate');
      Exit;
    end;

    LBuf[0] := 42;
    if not LBuf.Allocate(200) then
    begin
      WriteLn('FAIL - second allocate');
      Exit;
    end;

    if LBuf.Capacity <> 200 then
    begin
      WriteLn('FAIL - capacity not 200');
      Exit;
    end;

    if not LBuf.Allocate(50) then
    begin
      WriteLn('FAIL - third allocate');
      Exit;
    end;

    if LBuf.Capacity <> 50 then
    begin
      WriteLn('FAIL - capacity not 50');
      Exit;
    end;

    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure RunTests(const ATestNum: Integer);
begin
  WriteLn('=== UTest.VirtualBuffer ===');
  case ATestNum of
    1: Test_AllocateBasic();
    2: Test_AllocateZero();
    3: Test_TypedAccess();
    4: Test_FillAndSearch();
    5: Test_ZeroMemory();
    6: Test_CopyFrom();
    7: Test_ReallocMultiple();
  else
    Test_AllocateBasic();
    Test_AllocateZero();
    Test_TypedAccess();
    Test_FillAndSearch();
    Test_ZeroMemory();
    Test_CopyFrom();
    Test_ReallocMultiple();
  end;
  WriteLn('');
end;

end.
