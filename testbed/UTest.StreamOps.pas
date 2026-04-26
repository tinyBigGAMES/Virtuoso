unit UTest.StreamOps;

interface

procedure RunTests(const ATestNum: Integer);

implementation

uses
  System.SysUtils,
  System.Classes,
  Virtuoso;

procedure Test_SequentialReadWrite();
var
  LBuf: TVirtuoso<Byte>;
  LWriteData: array[0..99] of Byte;
  LReadData: array[0..99] of Byte;
  LIndex: Integer;
  LCount: UInt64;
begin
  Write('  SequentialReadWrite: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(100) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    for LIndex := 0 to 99 do
      LWriteData[LIndex] := Byte(LIndex);
    LBuf.Position := 0;
    LBuf.Write(LWriteData, 100);
    LBuf.Position := 0;
    FillChar(LReadData, SizeOf(LReadData), 0);
    LCount := LBuf.Read(LReadData, 100);
    if LCount <> 100 then
    begin WriteLn('FAIL - read count <> 100'); Exit; end;
    for LIndex := 0 to 99 do
    begin
      if LReadData[LIndex] <> Byte(LIndex) then
      begin WriteLn('FAIL - mismatch at ' + IntToStr(LIndex)); Exit; end;
    end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_SeekAllOrigins();
var
  LBuf: TVirtuoso<Byte>;
  LPos: UInt64;
begin
  Write('  SeekAllOrigins: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(100) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LPos := LBuf.Seek(0, soBeginning);
    if LPos <> 0 then
    begin WriteLn('FAIL - soBeginning <> 0'); Exit; end;
    LBuf.Seek(10, soBeginning);
    LPos := LBuf.Seek(5, soCurrent);
    if LPos <> 15 then
    begin WriteLn('FAIL - soCurrent, expected 15'); Exit; end;
    LPos := LBuf.Seek(-1, soEnd);
    if LPos <> LBuf.Size - 1 then
    begin WriteLn('FAIL - soEnd'); Exit; end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_SeekOutOfBounds();
var
  LBuf: TVirtuoso<Byte>;
  LRaised: Boolean;
begin
  Write('  SeekOutOfBounds: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(10) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LRaised := False;
    try
      LBuf.Seek(100, soBeginning);
    except
      on E: EArgumentOutOfRangeException do
        LRaised := True;
    end;
    if not LRaised then
    begin WriteLn('FAIL - no exception on seek past end'); Exit; end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_Eob();
var
  LBuf: TVirtuoso<Byte>;
begin
  Write('  Eob: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(10) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LBuf.Position := 0;
    if LBuf.Eob() then
    begin WriteLn('FAIL - eob at start'); Exit; end;
    LBuf.Position := LBuf.Size;
    if not LBuf.Eob() then
    begin WriteLn('FAIL - not eob at end'); Exit; end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_StringRoundTrip();
var
  LBuf: TVirtuoso<Byte>;
  LStr: string;
begin
  Write('  StringRoundTrip: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(4096) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LBuf.Position := 0;
    LBuf.WriteString('Hello');
    LBuf.WriteString('');
    LBuf.WriteString('World! Unicode: '#$00E9#$00F1#$00FC);
    LBuf.Position := 0;
    LStr := LBuf.ReadString();
    if LStr <> 'Hello' then
    begin WriteLn('FAIL - first string: ' + LStr); Exit; end;
    LStr := LBuf.ReadString();
    if LStr <> '' then
    begin WriteLn('FAIL - empty string'); Exit; end;
    LStr := LBuf.ReadString();
    if LStr <> 'World! Unicode: '#$00E9#$00F1#$00FC then
    begin WriteLn('FAIL - unicode string'); Exit; end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_PartialRead();
var
  LBuf: TVirtuoso<Byte>;
  LData: array[0..19] of Byte;
  LCount: UInt64;
begin
  Write('  PartialRead: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(100) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LBuf.Fill(77);
    LBuf.Position := 90;
    FillChar(LData, SizeOf(LData), 0);
    LCount := LBuf.Read(LData, 20);
    if LCount <> 10 then
    begin WriteLn('FAIL - expected 10 bytes, got ' + IntToStr(LCount)); Exit; end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_BytesOverload();
var
  LBuf: TVirtuoso<Byte>;
  LBytes: TBytes;
  LReadBytes: TBytes;
  LCount: UInt64;
  LIndex: Integer;
begin
  Write('  BytesOverload: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(256) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    SetLength(LBytes, 50);
    for LIndex := 0 to 49 do
      LBytes[LIndex] := Byte(LIndex + 10);
    LBuf.Position := 0;
    LCount := LBuf.Write(LBytes, 0, 50);
    if LCount <> 50 then
    begin WriteLn('FAIL - write count'); Exit; end;
    LBuf.Position := 0;
    SetLength(LReadBytes, 50);
    LCount := LBuf.Read(LReadBytes, 0, 50);
    if LCount <> 50 then
    begin WriteLn('FAIL - read count'); Exit; end;
    for LIndex := 0 to 49 do
    begin
      if LReadBytes[LIndex] <> LBytes[LIndex] then
      begin WriteLn('FAIL - mismatch at ' + IntToStr(LIndex)); Exit; end;
    end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure RunTests(const ATestNum: Integer);
begin
  WriteLn('=== UTest.StreamOps ===');
  case ATestNum of
    1: Test_SequentialReadWrite();
    2: Test_SeekAllOrigins();
    3: Test_SeekOutOfBounds();
    4: Test_Eob();
    5: Test_StringRoundTrip();
    6: Test_PartialRead();
    7: Test_BytesOverload();
  else
    Test_SequentialReadWrite();
    Test_SeekAllOrigins();
    Test_SeekOutOfBounds();
    Test_Eob();
    Test_StringRoundTrip();
    Test_PartialRead();
    Test_BytesOverload();
  end;
  WriteLn('');
end;

end.
