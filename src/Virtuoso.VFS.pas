{===============================================================================
  Virtuoso™ VFS - Read-only virtual file system (pack file)

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  Packs multiple files into a single container archive, then provides
  instant memory-mapped access to any entry via TVirtuosoView<Byte>.
  Built entirely on top of TVirtuoso<Byte>.
===============================================================================}

unit Virtuoso.VFS;

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.Generics.Collections,
  Virtuoso;

const
  VFS_MAGIC: array[0..3] of AnsiChar = 'VPK0';
  VFS_VERSION = 1;
  VFS_FILE_EXTENSION = 'vpk';

type

  { TVFSHeader }
  TVFSHeader = packed record
    Magic: array[0..3] of AnsiChar;
    Version: UInt32;
    EntryCount: UInt32;
    DataStartOffset: UInt64;
    Reserved: array[0..31] of Byte;
  end;

  { TVFSEntry }
  TVFSEntry = packed record
    EntryPath: array[0..259] of Char;
    Offset: UInt64;
    EntrySize: UInt64;
    Checksum: UInt32;
    Flags: UInt32;
  end;

  { TVFSPackStatus }
  TVFSPackStatus = (
    vpsStarting,
    vpsFileBegin,
    vpsFileEnd,
    vpsCompleted,
    vpsError
  );

  { TVFSPackInfo }
  TVFSPackInfo = record
    Status: TVFSPackStatus;
    Filename: string;
    EntryPath: string;
    FileIndex: Integer;
    FileCount: Integer;
    FileSize: UInt64;
    BytesWritten: UInt64;
    TotalBytes: UInt64;
    ErrorMessage: string;
  end;

  { TVFSPackCallback }
  TVFSPackCallback = reference to procedure(
    const AInfo: TVFSPackInfo;
    var ACancel: Boolean;
    const AUserData: Pointer
  );

  { TVirtuosoVFS }
  TVirtuosoVFS = class
  private
    FArchive: TVirtuoso<Byte>;
    FHeader: TVFSHeader;
    FEntries: TArray<TVFSEntry>;
    FLookup: TDictionary<string, Integer>;
    FIsOpen: Boolean;

    class function NormalizePath(const APath: string): string; static;
    class function ComputeCRC32(const AData: Pointer;
      const ASize: UInt64): UInt32; static;
    class procedure SetEntryPath(var AEntry: TVFSEntry;
      const APath: string); static;
    class function GetEntryPath(
      const AEntry: TVFSEntry): string; static;
  public
    constructor Create(); virtual;
    destructor Destroy(); override;

    function Open(const AFilename: string): Boolean;
    procedure Close();
    function IsOpen(): Boolean;
    function FileExists(const APath: string): Boolean;
    function OpenFile(const APath: string): TVirtuosoView<Byte>;
    function FileSize(const APath: string): UInt64;
    function EntryCount(): Integer;
    function ListFiles(): TArray<string>; overload;
    function ListFiles(
      const ADirectory: string): TArray<string>; overload;

    class function PackDirectory(
      const ASourceDir: string;
      const AOutputFile: string;
      const ACallback: TVFSPackCallback = nil;
      const AUserData: Pointer = nil
    ): Boolean; static;
  end;

implementation

var
  GCRC32Table: array[0..255] of UInt32;

procedure InitCRC32Table();
var
  LIndex: Integer;
  LBit: Integer;
  LCRC: UInt32;
begin
  for LIndex := 0 to 255 do
  begin
    LCRC := UInt32(LIndex);
    for LBit := 0 to 7 do
    begin
      if (LCRC and 1) <> 0 then
        LCRC := (LCRC shr 1) xor $EDB88320
      else
        LCRC := LCRC shr 1;
    end;
    GCRC32Table[LIndex] := LCRC;
  end;
end;

{ TVirtuosoVFS }
class function TVirtuosoVFS.NormalizePath(const APath: string): string;
begin
  Result := APath.Replace('\', '/').ToLower();
end;

class function TVirtuosoVFS.ComputeCRC32(const AData: Pointer;
  const ASize: UInt64): UInt32;
var
  LPtr: PByte;
  LRemaining: UInt64;
begin
  Result := $FFFFFFFF;
  LPtr := PByte(AData);
  LRemaining := ASize;
  while LRemaining > 0 do
  begin
    Result := GCRC32Table[(Result xor LPtr^) and $FF] xor (Result shr 8);
    Inc(LPtr);
    Dec(LRemaining);
  end;
  Result := Result xor $FFFFFFFF;
end;

class procedure TVirtuosoVFS.SetEntryPath(var AEntry: TVFSEntry;
  const APath: string);
var
  LLen: Integer;
begin
  FillChar(AEntry.EntryPath, SizeOf(AEntry.EntryPath), 0);
  LLen := Length(APath);
  if LLen > 259 then
    LLen := 259;
  if LLen > 0 then
    CopyMemory(@AEntry.EntryPath[0], PChar(APath), LLen * SizeOf(Char));
end;
class function TVirtuosoVFS.GetEntryPath(
  const AEntry: TVFSEntry): string;
var
  LLen: Integer;
begin
  LLen := 0;
  while (LLen < 260) and (AEntry.EntryPath[LLen] <> #0) do
    Inc(LLen);
  SetString(Result, PChar(@AEntry.EntryPath[0]), LLen);
end;

constructor TVirtuosoVFS.Create();
begin
  inherited Create();
  FArchive := TVirtuoso<Byte>.Create();
  FLookup := TDictionary<string, Integer>.Create();
  FIsOpen := False;
end;

destructor TVirtuosoVFS.Destroy();
begin
  Close();
  FLookup.Free();
  FArchive.Free();
  inherited;
end;
function TVirtuosoVFS.Open(const AFilename: string): Boolean;
var
  LFilename: string;
  LHeaderPtr: Pointer;
  LEntryPtr: Pointer;
  LIndex: Integer;
  LPath: string;
begin
  Result := False;
  Close();

  // Force the canonical extension
  LFilename := TPath.ChangeExtension(AFilename, VFS_FILE_EXTENSION);

  if not FArchive.Open(LFilename, vmReadOnly) then
    Exit;

  // Validate minimum size for header
  if FArchive.Size < UInt64(SizeOf(TVFSHeader)) then
  begin
    FArchive.Close();
    Exit;
  end;

  // Read header
  LHeaderPtr := FArchive.Memory;
  CopyMemory(@FHeader, LHeaderPtr, SizeOf(TVFSHeader));

  // Validate magic
  if (FHeader.Magic[0] <> VFS_MAGIC[0]) or
     (FHeader.Magic[1] <> VFS_MAGIC[1]) or
     (FHeader.Magic[2] <> VFS_MAGIC[2]) or
     (FHeader.Magic[3] <> VFS_MAGIC[3]) then
  begin
    FArchive.Close();
    Exit;
  end;
  // Validate version
  if FHeader.Version <> VFS_VERSION then
  begin
    FArchive.Close();
    Exit;
  end;

  // Validate size covers directory
  if FArchive.Size < UInt64(SizeOf(TVFSHeader)) +
     (UInt64(FHeader.EntryCount) * UInt64(SizeOf(TVFSEntry))) then
  begin
    FArchive.Close();
    Exit;
  end;

  // Read directory entries
  SetLength(FEntries, FHeader.EntryCount);
  if FHeader.EntryCount > 0 then
  begin
    LEntryPtr := Pointer(
      UIntPtr(FArchive.Memory) + UIntPtr(SizeOf(TVFSHeader)));
    CopyMemory(@FEntries[0], LEntryPtr,
      UInt64(FHeader.EntryCount) * UInt64(SizeOf(TVFSEntry)));
  end;

  // Build lookup dictionary (keys already lowercased from pack)
  FLookup.Clear();
  for LIndex := 0 to Integer(FHeader.EntryCount) - 1 do
  begin
    LPath := GetEntryPath(FEntries[LIndex]);
    FLookup.AddOrSetValue(LPath, LIndex);
  end;

  FIsOpen := True;
  Result := True;
end;

procedure TVirtuosoVFS.Close();
begin
  FLookup.Clear();
  SetLength(FEntries, 0);
  FillChar(FHeader, SizeOf(FHeader), 0);
  FArchive.Close();
  FIsOpen := False;
end;

function TVirtuosoVFS.IsOpen(): Boolean;
begin
  Result := FIsOpen;
end;
function TVirtuosoVFS.FileExists(const APath: string): Boolean;
begin
  Result := FIsOpen and FLookup.ContainsKey(NormalizePath(APath));
end;

function TVirtuosoVFS.OpenFile(
  const APath: string): TVirtuosoView<Byte>;
var
  LIndex: Integer;
  LEntry: TVFSEntry;
begin
  if not FIsOpen then
    raise EInvalidOperation.Create('VFS archive is not open');

  if not FLookup.TryGetValue(NormalizePath(APath), LIndex) then
    raise EFileNotFoundException.Create(
      'Entry not found in VFS: ' + APath);

  LEntry := FEntries[LIndex];

  // CreateView offset/count in bytes (T=Byte)
  Result := FArchive.CreateView(LEntry.Offset, LEntry.EntrySize);
end;

function TVirtuosoVFS.FileSize(const APath: string): UInt64;
var
  LIndex: Integer;
begin
  if not FIsOpen then
    raise EInvalidOperation.Create('VFS archive is not open');

  if not FLookup.TryGetValue(NormalizePath(APath), LIndex) then
    raise EFileNotFoundException.Create(
      'Entry not found in VFS: ' + APath);

  Result := FEntries[LIndex].EntrySize;
end;
function TVirtuosoVFS.EntryCount(): Integer;
begin
  if FIsOpen then
    Result := Integer(FHeader.EntryCount)
  else
    Result := 0;
end;

function TVirtuosoVFS.ListFiles(): TArray<string>;
var
  LIndex: Integer;
begin
  SetLength(Result, Length(FEntries));
  for LIndex := 0 to High(FEntries) do
    Result[LIndex] := GetEntryPath(FEntries[LIndex]);
end;

function TVirtuosoVFS.ListFiles(
  const ADirectory: string): TArray<string>;
var
  LPrefix: string;
  LList: TList<string>;
  LIndex: Integer;
  LPath: string;
begin
  LPrefix := NormalizePath(ADirectory);

  // Ensure prefix ends with /
  if (LPrefix <> '') and (not LPrefix.EndsWith('/')) then
    LPrefix := LPrefix + '/';

  LList := TList<string>.Create();
  try
    for LIndex := 0 to High(FEntries) do
    begin
      LPath := GetEntryPath(FEntries[LIndex]);
      if LPath.StartsWith(LPrefix) then
        LList.Add(LPath);
    end;
    Result := LList.ToArray();
  finally
    LList.Free();
  end;
end;
class function TVirtuosoVFS.PackDirectory(
  const ASourceDir: string;
  const AOutputFile: string;
  const ACallback: TVFSPackCallback;
  const AUserData: Pointer
): Boolean;
var
  LFiles: TArray<string>;
  LFileCount: Integer;
  LTotalDataSize: UInt64;
  LFileSizes: TArray<UInt64>;
  LRelPaths: TArray<string>;
  LIndex: Integer;
  LHeaderSize: UInt64;
  LDirSize: UInt64;
  LDataStart: UInt64;
  LArchiveSize: UInt64;
  LArchive: TVirtuoso<Byte>;
  LSource: TVirtuoso<Byte>;
  LHeader: TVFSHeader;
  LEntries: TArray<TVFSEntry>;
  LCurrentOffset: UInt64;
  LBytesWritten: UInt64;
  LInfo: TVFSPackInfo;
  LCancel: Boolean;
  LBaseDir: string;
  LOutputFile: string;
begin
  Result := False;

  // Validate source directory
  if not TDirectory.Exists(ASourceDir) then
    Exit;
  // Force canonical extension on output
  LOutputFile := TPath.ChangeExtension(AOutputFile, VFS_FILE_EXTENSION);

  // Scan all files recursively
  LFiles := TDirectory.GetFiles(ASourceDir, '*',
    TSearchOption.soAllDirectories);
  LFileCount := Length(LFiles);
  if LFileCount = 0 then
    Exit;

  // Collect sizes and relative paths
  SetLength(LFileSizes, LFileCount);
  SetLength(LRelPaths, LFileCount);
  LTotalDataSize := 0;

  LBaseDir := IncludeTrailingPathDelimiter(ASourceDir);

  for LIndex := 0 to LFileCount - 1 do
  begin
    LFileSizes[LIndex] := UInt64(TFile.GetSize(LFiles[LIndex]));
    LTotalDataSize := LTotalDataSize + LFileSizes[LIndex];

    // Build relative path, normalized and lowercased
    LRelPaths[LIndex] := NormalizePath(
      Copy(LFiles[LIndex], Length(LBaseDir) + 1, MaxInt));
  end;

  // Compute layout
  LHeaderSize := UInt64(SizeOf(TVFSHeader));
  LDirSize := UInt64(LFileCount) * UInt64(SizeOf(TVFSEntry));
  LDataStart := LHeaderSize + LDirSize;
  LArchiveSize := LDataStart + LTotalDataSize;
  // Fire vpsStarting callback
  if Assigned(ACallback) then
  begin
    FillChar(LInfo, SizeOf(LInfo), 0);
    LInfo.Status := vpsStarting;
    LInfo.FileCount := LFileCount;
    LInfo.TotalBytes := LTotalDataSize;
    LCancel := False;
    ACallback(LInfo, LCancel, AUserData);
    if LCancel then
      Exit;
  end;

  // Build directory entries with pre-computed offsets
  SetLength(LEntries, LFileCount);
  LCurrentOffset := LDataStart;
  for LIndex := 0 to LFileCount - 1 do
  begin
    FillChar(LEntries[LIndex], SizeOf(TVFSEntry), 0);
    SetEntryPath(LEntries[LIndex], LRelPaths[LIndex]);
    LEntries[LIndex].Offset := LCurrentOffset;
    LEntries[LIndex].EntrySize := LFileSizes[LIndex];
    LEntries[LIndex].Flags := 0;
    LCurrentOffset := LCurrentOffset + LFileSizes[LIndex];
  end;
  // Allocate the archive buffer
  LArchive := TVirtuoso<Byte>.Create();
  try
    if not LArchive.Allocate(LArchiveSize) then
      Exit;

    LArchive.ZeroMemory();

    // Write header
    FillChar(LHeader, SizeOf(LHeader), 0);
    Move(VFS_MAGIC, LHeader.Magic, SizeOf(LHeader.Magic));
    LHeader.Version := VFS_VERSION;
    LHeader.EntryCount := UInt32(LFileCount);
    LHeader.DataStartOffset := LDataStart;

    CopyMemory(LArchive.Memory, @LHeader, SizeOf(TVFSHeader));

    // Copy file data and compute checksums
    LBytesWritten := 0;
    LSource := TVirtuoso<Byte>.Create();
    try
      for LIndex := 0 to LFileCount - 1 do
      begin
        // Fire vpsFileBegin
        if Assigned(ACallback) then
        begin
          LInfo.Status := vpsFileBegin;
          LInfo.Filename := LFiles[LIndex];
          LInfo.EntryPath := LRelPaths[LIndex];
          LInfo.FileIndex := LIndex + 1;
          LInfo.FileCount := LFileCount;
          LInfo.FileSize := LFileSizes[LIndex];
          LInfo.BytesWritten := LBytesWritten;
          LInfo.TotalBytes := LTotalDataSize;
          LInfo.ErrorMessage := '';
          LCancel := False;
          ACallback(LInfo, LCancel, AUserData);
          if LCancel then
            Exit;
        end;
        // Copy file data (skip zero-size files)
        if LFileSizes[LIndex] > 0 then
        begin
          if not LSource.Open(LFiles[LIndex], vmReadOnly) then
          begin
            // Fire error callback
            if Assigned(ACallback) then
            begin
              LInfo.Status := vpsError;
              LInfo.ErrorMessage := 'Failed to open: ' + LFiles[LIndex];
              LCancel := False;
              ACallback(LInfo, LCancel, AUserData);
            end;
            Exit;
          end;

          CopyMemory(
            Pointer(UIntPtr(LArchive.Memory) +
              UIntPtr(LEntries[LIndex].Offset)),
            LSource.Memory,
            LFileSizes[LIndex]);

          // Compute CRC32 checksum from the source data
          LEntries[LIndex].Checksum := ComputeCRC32(
            LSource.Memory, LFileSizes[LIndex]);

          LSource.Close();
        end;

        LBytesWritten := LBytesWritten + LFileSizes[LIndex];
        // Fire vpsFileEnd
        if Assigned(ACallback) then
        begin
          LInfo.Status := vpsFileEnd;
          LInfo.BytesWritten := LBytesWritten;
          LCancel := False;
          ACallback(LInfo, LCancel, AUserData);
          if LCancel then
            Exit;
        end;
      end;
    finally
      LSource.Free();
    end;

    // Write directory entries (after checksums are computed)
    if LFileCount > 0 then
      CopyMemory(
        Pointer(UIntPtr(LArchive.Memory) + UIntPtr(SizeOf(TVFSHeader))),
        @LEntries[0],
        UInt64(LFileCount) * UInt64(SizeOf(TVFSEntry)));

    // Save to disk
    LArchive.SaveToFile(LOutputFile);
    Result := True;

    // Fire vpsCompleted
    if Assigned(ACallback) then
    begin
      LInfo.Status := vpsCompleted;
      LInfo.BytesWritten := LBytesWritten;
      LInfo.ErrorMessage := '';
      LCancel := False;
      ACallback(LInfo, LCancel, AUserData);
    end;
  finally
    LArchive.Free();
  end;
end;

initialization
  InitCRC32Table();

end.