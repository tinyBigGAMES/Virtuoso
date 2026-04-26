unit UTestbed;

interface

procedure RunTestbed();

implementation

uses
  System.SysUtils,
  UTest.VirtualBuffer,
  UTest.VFS,
  UTest.SubViews,
  UTest.StreamOps,
  UTest.StreamAdapter,
  UTest.SharedMemory,
  UTest.FileMapping,
  UTest.FileIO,
  UTest.Enumeration,
  UTest.AutoGrow;

procedure Pause();
begin
  Write('Press ENTER to continue...');
  ReadLn;
  WriteLn;
end;

procedure RunTestbed();
var
  LIndex: Integer;
begin
  try

    LIndex := 0;

    case LIndex of
      01: UTest.AutoGrow.RunTests(0);
      02: UTest.Enumeration.RunTests(0);
      03: UTest.FileIO.RunTests(0);
      04: UTest.FileMapping.RunTests(0);
      05: UTest.SharedMemory.RunTests(0);
      06: UTest.StreamAdapter.RunTests(0);
      07: UTest.StreamOps.RunTests(0);
      08: UTest.SubViews.RunTests(0);
      09: UTest.VFS.RunTests(0);
      10: UTest.VirtualBuffer.RunTests(0);
    else
      UTest.AutoGrow.RunTests(0);
      UTest.Enumeration.RunTests(0);
      UTest.FileIO.RunTests(0);
      UTest.FileMapping.RunTests(0);
      UTest.SharedMemory.RunTests(0);
      UTest.StreamAdapter.RunTests(0);
      UTest.StreamOps.RunTests(0);
      UTest.SubViews.RunTests(0);
      UTest.VFS.RunTests(0);
      UTest.VirtualBuffer.RunTests(0);
    end;
  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn(Format('EXCEPTION: %s', [E.Message]));
    end;
  end;

  Pause();
end;

end.
