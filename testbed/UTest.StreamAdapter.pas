unit UTest.StreamAdapter;

interface

procedure RunTests(const ATestNum: Integer);

implementation

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  Virtuoso;

procedure Test_CreateStream();
var
  LBuf: TVirtuoso<Byte>;
  LStream: TStream;
begin
  Write('  CreateStream: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(512) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LStream := LBuf.CreateStream();
    try
      if LStream = nil then
      begin WriteLn('FAIL - nil stream'); Exit; end;
      if LStream.Size <> LBuf.Size then
      begin WriteLn('FAIL - size mismatch'); Exit; end;
      WriteLn('PASS');
    finally
      LStream.Free();
    end;
  finally
    LBuf.Free();
  end;
end;

procedure Test_StreamReadWrite();
var
  LBuf: TVirtuoso<Byte>;
  LStream: TStream;
  LWriteData: array[0..9] of Byte;
  LReadData: array[0..9] of Byte;
  LIndex: Integer;
begin
  Write('  StreamReadWrite: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(64) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    for LIndex := 0 to 9 do
      LWriteData[LIndex] := Byte(LIndex + 100);
    LStream := LBuf.CreateStream();
    try
      LStream.WriteBuffer(LWriteData, 10);
      LStream.Position := 0;
      FillChar(LReadData, SizeOf(LReadData), 0);
      LStream.ReadBuffer(LReadData, 10);
      for LIndex := 0 to 9 do
      begin
        if LReadData[LIndex] <> LWriteData[LIndex] then
        begin WriteLn('FAIL - mismatch at ' + IntToStr(LIndex)); Exit; end;
      end;
      WriteLn('PASS');
    finally
      LStream.Free();
    end;
  finally
    LBuf.Free();
  end;
end;

procedure Test_StreamIndependentPosition();
var
  LBuf: TVirtuoso<Byte>;
  LStream: TStream;
begin
  Write('  StreamIndependentPosition: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(256) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LBuf.Position := 50;
    LStream := LBuf.CreateStream();
    try
      if LStream.Position <> 0 then
      begin WriteLn('FAIL - stream not at 0'); Exit; end;
      LStream.Position := 100;
      if LBuf.Position <> 50 then
      begin WriteLn('FAIL - parent position changed'); Exit; end;
      WriteLn('PASS');
    finally
      LStream.Free();
    end;
  finally
    LBuf.Free();
  end;
end;

procedure Test_StreamReadOnlyWrite();
var
  LBuf: TVirtuoso<Byte>;
  LStream: TStream;
  LFile: string;
  LFS: TFileStream;
  LRaised: Boolean;
  LByte: Byte;
begin
  Write('  StreamReadOnlyWrite: ');
  LFile := TPath.Combine(TPath.GetTempPath(), 'virt_streamro.bin');
  try
    LFS := TFileStream.Create(LFile, fmCreate);
    try
      LByte := 42;
      LFS.WriteBuffer(LByte, 1);
    finally
      LFS.Free();
    end;
    LBuf := TVirtuoso<Byte>.Create();
    try
      LBuf.Open(LFile, vmReadOnly);
      LStream := LBuf.CreateStream();
      try
        LRaised := False;
        LByte := 99;
        try
          LStream.WriteBuffer(LByte, 1);
        except
          on E: EInvalidOperation do
            LRaised := True;
        end;
        if not LRaised then
        begin WriteLn('FAIL - no exception'); Exit; end;
        WriteLn('PASS');
      finally
        LStream.Free();
      end;
    finally
      LBuf.Free();
    end;
  finally
    if TFile.Exists(LFile) then
      TFile.Delete(LFile);
  end;
end;

procedure Test_StreamWithTStreamReader();
var
  LBuf: TVirtuoso<Byte>;
  LStream: TStream;
  LReader: TStreamReader;
  LText: UTF8String;
  LLine: string;
begin
  Write('  StreamWithTStreamReader: ');
  LBuf := TVirtuoso<Byte>.Create();
  try
    if not LBuf.Allocate(1024) then
    begin WriteLn('FAIL - allocate'); Exit; end;
    LText := 'Line one' + #13#10 + 'Line two' + #13#10;
    LBuf.Position := 0;
    LBuf.Write(LText[1], Length(LText));
    LStream := LBuf.CreateStream();
    try
      LReader := TStreamReader.Create(LStream, TEncoding.UTF8);
      try
        LLine := LReader.ReadLine();
        if LLine <> 'Line one' then
        begin WriteLn('FAIL - first line: ' + LLine); Exit; end;
        LLine := LReader.ReadLine();
        if LLine <> 'Line two' then
        begin WriteLn('FAIL - second line: ' + LLine); Exit; end;
        WriteLn('PASS');
      finally
        LReader.Free();
      end;
    finally
      // TStreamReader frees stream (OwnsStream default true)
    end;
  finally
    LBuf.Free();
  end;
end;

procedure RunTests(const ATestNum: Integer);
begin
  WriteLn('=== UTest.StreamAdapter ===');
  case ATestNum of
    1: Test_CreateStream();
    2: Test_StreamReadWrite();
    3: Test_StreamIndependentPosition();
    4: Test_StreamReadOnlyWrite();
    5: Test_StreamWithTStreamReader();
  else
    Test_CreateStream();
    Test_StreamReadWrite();
    Test_StreamIndependentPosition();
    Test_StreamReadOnlyWrite();
    Test_StreamWithTStreamReader();
  end;
  WriteLn('');
end;

end.
