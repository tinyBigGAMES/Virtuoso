unit UTest.SharedMemory;

interface

procedure RunTests(const ATestNum: Integer);

implementation

uses
  System.SysUtils,
  System.Classes,
  Virtuoso;

procedure Test_NamedAllocate();
var
  LBuf: TVirtuoso<Byte>;
begin
  Write('  NamedAllocate: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(100, 'VirtuosoTest_Named') then
    begin WriteLn('FAIL - allocate'); Exit; end;
    if LBuf.MappingName <> 'VirtuosoTest_Named' then
    begin WriteLn('FAIL - name mismatch'); Exit; end;
    if not LBuf.IsSharedOwner then
    begin WriteLn('FAIL - not shared owner'); Exit; end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_OpenSharedReadWrite();
var
  LProducer: TVirtuoso<Integer>;
  LConsumer: TVirtuoso<Integer>;
begin
  Write('  OpenSharedReadWrite: ');
  LProducer := TVirtuoso<Integer>.Create();
  LConsumer := TVirtuoso<Integer>.Create();
  try
    if not LProducer.Allocate(10, 'VirtuosoTest_SharedRW') then
    begin WriteLn('FAIL - producer allocate'); Exit; end;
    LProducer[0] := 12345;
    LProducer[9] := 67890;
    if not LConsumer.OpenShared('VirtuosoTest_SharedRW', 10) then
    begin WriteLn('FAIL - consumer open'); Exit; end;
    if LConsumer.IsSharedOwner then
    begin WriteLn('FAIL - consumer should not be owner'); Exit; end;
    if LConsumer[0] <> 12345 then
    begin WriteLn('FAIL - data[0] mismatch'); Exit; end;
    if LConsumer[9] <> 67890 then
    begin WriteLn('FAIL - data[9] mismatch'); Exit; end;
    WriteLn('PASS');
  finally
    LConsumer.Free();
    LProducer.Free();
  end;
end;

procedure Test_OpenSharedReadOnly();
var
  LProducer: TVirtuoso<Byte>;
  LConsumer: TVirtuoso<Byte>;
  LRaised: Boolean;
begin
  Write('  OpenSharedReadOnly: ');
  LProducer := TVirtuoso<Byte>.Create();
  LConsumer := TVirtuoso<Byte>.Create();
  try
    if not LProducer.Allocate(50, 'VirtuosoTest_SharedRO') then
    begin WriteLn('FAIL - producer allocate'); Exit; end;
    LProducer[0] := 42;
    if not LConsumer.OpenShared('VirtuosoTest_SharedRO', 50, True) then
    begin WriteLn('FAIL - consumer open'); Exit; end;
    if not LConsumer.IsReadOnly then
    begin WriteLn('FAIL - consumer not read-only'); Exit; end;
    if LConsumer[0] <> 42 then
    begin WriteLn('FAIL - data mismatch'); Exit; end;
    LRaised := False;
    try
      LConsumer[0] := 99;
    except
      on E: EInvalidOperation do
        LRaised := True;
    end;
    if not LRaised then
    begin WriteLn('FAIL - no exception on write'); Exit; end;
    WriteLn('PASS');
  finally
    LConsumer.Free();
    LProducer.Free();
  end;
end;

procedure Test_DuplicateNameFails();
var
  LBuf1: TVirtuoso<Byte>;
  LBuf2: TVirtuoso<Byte>;
begin
  Write('  DuplicateNameFails: ');
  LBuf1 := TVirtuoso<Byte>.Create();
  LBuf2 := TVirtuoso<Byte>.Create();
  try
    if not LBuf1.Allocate(10, 'VirtuosoTest_Dup') then
    begin WriteLn('FAIL - first allocate'); Exit; end;
    if LBuf2.Allocate(10, 'VirtuosoTest_Dup') then
    begin WriteLn('FAIL - second allocate should fail'); Exit; end;
    if LBuf2.LastErrorCode <> 'VT19' then
    begin WriteLn('FAIL - expected VT19, got ' + LBuf2.LastErrorCode); Exit; end;
    WriteLn('PASS');
  finally
    LBuf2.Free();
    LBuf1.Free();
  end;
end;

procedure Test_OpenSharedMissing();
var
  LBuf: TVirtuoso<Byte>;
begin
  Write('  OpenSharedMissing: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if LBuf.OpenShared('VirtuosoTest_NoSuchMapping_XYZ', 10) then
    begin WriteLn('FAIL - should return False'); Exit; end;
    if LBuf.LastErrorCode <> 'VT16' then
    begin WriteLn('FAIL - expected VT16, got ' + LBuf.LastErrorCode); Exit; end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure RunTests(const ATestNum: Integer);
begin
  WriteLn('=== UTest.SharedMemory ===');
  case ATestNum of
    1: Test_NamedAllocate();
    2: Test_OpenSharedReadWrite();
    3: Test_OpenSharedReadOnly();
    4: Test_DuplicateNameFails();
    5: Test_OpenSharedMissing();
  else
    Test_NamedAllocate();
    Test_OpenSharedReadWrite();
    Test_OpenSharedReadOnly();
    Test_DuplicateNameFails();
    Test_OpenSharedMissing();
  end;
  WriteLn('');
end;

end.
