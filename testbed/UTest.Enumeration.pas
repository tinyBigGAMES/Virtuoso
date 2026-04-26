unit UTest.Enumeration;

interface

procedure RunTests(const ATestNum: Integer);

implementation

uses
  System.SysUtils,
  Virtuoso;

type
  TTestVec3 = packed record
    X: Single;
    Y: Single;
    Z: Single;
  end;

procedure Test_ForInIntegers();
var
  LBuf: TVirtuoso<Integer>;
  LIndex: Integer;
  LVal: Integer;
  LSum: Int64;
  LExpectedSum: Int64;
  LCount: Integer;
begin
  Write('  ForInIntegers: ');
  LBuf := TVirtuoso<Integer>.Create();
  try
    if not LBuf.Allocate(100) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LExpectedSum := 0;
    for LIndex := 0 to 99 do
    begin
      LBuf[LIndex] := LIndex;
      LExpectedSum := LExpectedSum + LIndex;
    end;
    LSum := 0;
    LCount := 0;
    for LVal in LBuf do
    begin
      LSum := LSum + LVal;
      Inc(LCount);
    end;
    if LCount <> 100 then
    begin WriteLn('FAIL - count <> 100'); Exit; end;
    if LSum <> LExpectedSum then
    begin WriteLn('FAIL - sum mismatch'); Exit; end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_ForInBytes();
var
  LBuf: TVirtuoso<Byte>;
  LIndex: Integer;
  LVal: Byte;
  LCount: Integer;
begin
  Write('  ForInBytes: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(256) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    for LIndex := 0 to 255 do
      LBuf[LIndex] := Byte(LIndex);
    LCount := 0;
    for LVal in LBuf do
      Inc(LCount);
    if UInt64(LCount) <> LBuf.Capacity then
    begin WriteLn('FAIL - count <> capacity'); Exit; end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_ForInRecords();
var
  LBuf: TVirtuoso<TTestVec3>;
  LIndex: Integer;
  LRec: TTestVec3;
  LCount: Integer;
begin
  Write('  ForInRecords: ');
  LBuf := TVirtuoso<TTestVec3>.Create();
  try
    if not LBuf.Allocate(10) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    for LIndex := 0 to 9 do
    begin
      LRec.X := LIndex * 1.0;
      LRec.Y := LIndex * 2.0;
      LRec.Z := LIndex * 3.0;
      LBuf[LIndex] := LRec;
    end;
    LCount := 0;
    for LRec in LBuf do
    begin
      if Round(LRec.X) <> LCount then
      begin WriteLn('FAIL - X mismatch at ' + IntToStr(LCount)); Exit; end;
      Inc(LCount);
    end;
    if LCount <> 10 then
    begin WriteLn('FAIL - count <> 10'); Exit; end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_ForInSingle();
var
  LBuf: TVirtuoso<Byte>;
  LVal: Byte;
  LCount: Integer;
begin
  Write('  ForInSingle: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(1) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LBuf[0] := 77;
    LCount := 0;
    for LVal in LBuf do
    begin
      if LVal <> 77 then
      begin WriteLn('FAIL - value <> 77'); Exit; end;
      Inc(LCount);
    end;
    if LCount <> 1 then
    begin WriteLn('FAIL - count <> 1'); Exit; end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure RunTests(const ATestNum: Integer);
begin
  WriteLn('=== UTest.Enumeration ===');
  case ATestNum of
    1: Test_ForInIntegers();
    2: Test_ForInBytes();
    3: Test_ForInRecords();
    4: Test_ForInSingle();
  else
    Test_ForInIntegers();
    Test_ForInBytes();
    Test_ForInRecords();
    Test_ForInSingle();
  end;
  WriteLn('');
end;

end.
