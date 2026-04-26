unit UTest.SubViews;

interface

procedure RunTests(const ATestNum: Integer);

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  Virtuoso;

procedure Test_CreateViewBasic();
var
  LBuf: TVirtuoso<Integer>;
  LView: TVirtuosoView<Integer>;
  LIndex: Integer;
begin
  Write('  CreateViewBasic: ');
  LBuf := TVirtuoso<Integer>.Create();
  try
    if not LBuf.Allocate(100) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    for LIndex := 0 to 99 do
      LBuf[LIndex] := LIndex * 3;
    LView := LBuf.CreateView(10, 20);
    try
      if not LView.IsOpen then
      begin WriteLn('FAIL - view not open'); Exit; end;
      if LView.Capacity <> 20 then
      begin WriteLn('FAIL - view capacity <> 20'); Exit; end;
      if LView[0] <> 30 then
      begin WriteLn('FAIL - View[0] <> 30'); Exit; end;
      if LView[19] <> LBuf[29] then
      begin WriteLn('FAIL - View[19] <> Parent[29]'); Exit; end;
      WriteLn('PASS');
    finally
      LView.Free();
    end;
  finally
    LBuf.Free();
  end;
end;

{$HINTS OFF}
procedure Test_ViewBoundsCheck();
var
  LBuf: TVirtuoso<Byte>;
  LView: TVirtuosoView<Byte>;
  LRaised: Boolean;
  LDummy: Byte;
begin
  Write('  ViewBoundsCheck: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(100) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LView := LBuf.CreateView(0, 10);
    try
      LDummy := LView[9];
      LRaised := False;
      try
        LDummy := LView[10];
      except
        on E: EArgumentOutOfRangeException do
          LRaised := True;
      end;
      if not LRaised then
      begin WriteLn('FAIL - no exception'); Exit; end;
      WriteLn('PASS');
    finally
      LView.Free();
    end;
  finally
    LBuf.Free();
  end;
end;
{$HINTS ON}

procedure Test_ViewOutOfParentBounds();
var
  LBuf: TVirtuoso<Byte>;
  LView: TVirtuosoView<Byte>;
  LRaised: Boolean;
begin
  Write('  ViewOutOfParentBounds: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(50) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LRaised := False;
    try
      LView := LBuf.CreateView(40, 20);
      LView.Free();
    except
      LRaised := True;
    end;
    if not LRaised then
    begin WriteLn('FAIL - no exception'); Exit; end;
    WriteLn('PASS');
  finally
    LBuf.Free();
  end;
end;

procedure Test_ViewReadWrite();
var
  LBuf: TVirtuoso<Byte>;
  LView: TVirtuosoView<Byte>;
  LData: array[0..4] of Byte;
  LCount: UInt64;
begin
  Write('  ViewReadWrite: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(100) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LBuf.ZeroMemory();
    LView := LBuf.CreateView(10, 20);
    try
      LData[0] := 11; LData[1] := 22; LData[2] := 33;
      LData[3] := 44; LData[4] := 55;
      LView.Position := 0;
      LCount := LView.Write(LData, 5);
      if LCount <> 5 then
      begin WriteLn('FAIL - write count'); Exit; end;
      if (LBuf[10] <> 11) or (LBuf[14] <> 55) then
      begin WriteLn('FAIL - parent mismatch'); Exit; end;
      LView.Position := 0;
      FillChar(LData, SizeOf(LData), 0);
      LCount := LView.Read(LData, 5);
      if (LCount <> 5) or (LData[0] <> 11) or (LData[4] <> 55) then
      begin WriteLn('FAIL - read back mismatch'); Exit; end;
      WriteLn('PASS');
    finally
      LView.Free();
    end;
  finally
    LBuf.Free();
  end;
end;

procedure Test_ViewReadOnly();
var
  LBuf: TVirtuoso<Byte>;
  LView: TVirtuosoView<Byte>;
  LFile: string;
  LFS: TFileStream;
  LRaised: Boolean;
  LByte: Byte;
begin
  Write('  ViewReadOnly: ');
  LFile := TPath.Combine(TPath.GetTempPath(), 'virt_viewro.bin');
  try
    LFS := TFileStream.Create(LFile, fmCreate);
    try
      for LByte := 0 to 63 do
        LFS.WriteBuffer(LByte, 1);
    finally
      LFS.Free();
    end;
    LBuf := TVirtuoso<Byte>.Create();
    try
      LBuf.Open(LFile, vmReadOnly);
      LView := LBuf.CreateView(0, 10);
      try
        LRaised := False;
        try
          LView[0] := 99;
        except
          on E: EInvalidOperation do
            LRaised := True;
        end;
        if not LRaised then
        begin WriteLn('FAIL - no exception'); Exit; end;
        WriteLn('PASS');
      finally
        LView.Free();
      end;
    finally
      LBuf.Free();
    end;
  finally
    if TFile.Exists(LFile) then
      TFile.Delete(LFile);
  end;
end;

procedure Test_ViewPosition();
var
  LBuf: TVirtuoso<Byte>;
  LView: TVirtuosoView<Byte>;
begin
  Write('  ViewPosition: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(100) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LView := LBuf.CreateView(0, 20);
    try
      LView.Position := 0;
      if LView.Eob() then
      begin WriteLn('FAIL - eob at start'); Exit; end;
      LView.Position := LView.Size;
      if not LView.Eob() then
      begin WriteLn('FAIL - not eob at end'); Exit; end;
      WriteLn('PASS');
    finally
      LView.Free();
    end;
  finally
    LBuf.Free();
  end;
end;

procedure Test_MultipleViews();
var
  LBuf: TVirtuoso<Byte>;
  LView1: TVirtuosoView<Byte>;
  LView2: TVirtuosoView<Byte>;
  LView3: TVirtuosoView<Byte>;
begin
  Write('  MultipleViews: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(90) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LBuf.ZeroMemory();
    LView1 := LBuf.CreateView(0, 30);
    LView2 := LBuf.CreateView(30, 30);
    LView3 := LBuf.CreateView(60, 30);
    try
      LView1[0] := 11;
      LView2[0] := 22;
      LView3[0] := 33;
      if (LBuf[0] <> 11) or (LBuf[30] <> 22) or (LBuf[60] <> 33) then
      begin WriteLn('FAIL - parent mismatch'); Exit; end;
      WriteLn('PASS');
    finally
      LView3.Free();
      LView2.Free();
      LView1.Free();
    end;
  finally
    LBuf.Free();
  end;
end;

procedure RunTests(const ATestNum: Integer);
begin
  WriteLn('=== UTest.SubViews ===');
  case ATestNum of
    1: Test_CreateViewBasic();
    2: Test_ViewBoundsCheck();
    3: Test_ViewOutOfParentBounds();
    4: Test_ViewReadWrite();
    5: Test_ViewReadOnly();
    6: Test_ViewPosition();
    7: Test_MultipleViews();
  else
    Test_CreateViewBasic();
    Test_ViewBoundsCheck();
    Test_ViewOutOfParentBounds();
    Test_ViewReadWrite();
    Test_ViewReadOnly();
    Test_ViewPosition();
    Test_MultipleViews();
  end;
  WriteLn('');
end;

end.
