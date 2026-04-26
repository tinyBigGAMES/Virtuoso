program Testbed;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.SysUtils,
  Virtuoso in '..\src\Virtuoso.pas',
  Virtuoso.VFS in '..\src\Virtuoso.VFS.pas',
  UTest.AutoGrow in 'UTest.AutoGrow.pas',
  UTest.Enumeration in 'UTest.Enumeration.pas',
  UTest.FileIO in 'UTest.FileIO.pas',
  UTest.FileMapping in 'UTest.FileMapping.pas',
  UTest.SharedMemory in 'UTest.SharedMemory.pas',
  UTest.StreamAdapter in 'UTest.StreamAdapter.pas',
  UTest.StreamOps in 'UTest.StreamOps.pas',
  UTest.SubViews in 'UTest.SubViews.pas',
  UTest.VFS in 'UTest.VFS.pas',
  UTest.VirtualBuffer in 'UTest.VirtualBuffer.pas',
  UTestbed in 'UTestbed.pas';

begin
  RunTestbed();
end.
