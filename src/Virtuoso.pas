{===============================================================================
  Virtuoso™ - High-performance memory-mapped buffer and file access

  Copyright © 2026-present tinyBigGAMES™ LLC
  All Rights Reserved.

  A unified, thread-safe, generic memory-mapped class combining anonymous
  buffers and file-backed views into a single, feature-rich API. Supports
  read-only, read-write, copy-on-write, and anonymous allocation modes
  with MREW concurrency, TStream interop, zero-copy sub-views, auto-grow,
  and typed enumerator support.
===============================================================================}

unit Virtuoso;

interface

uses
  WinApi.Windows,
  System.SysUtils,
  System.IOUtils,
  System.Classes,
  System.SyncObjs;

const
  // Error codes for OS-level failures (programmer errors use exceptions).
  VT_ERROR_ALLOC_SIZE_ZERO     = 'VT01';
  VT_ERROR_ALLOC_MAPPING       = 'VT02';
  VT_ERROR_ALLOC_MAPVIEW       = 'VT03';
  VT_ERROR_ALLOC_EXCEPTION     = 'VT04';
  VT_ERROR_LOAD_ALIGNMENT      = 'VT05';
  VT_ERROR_LOAD_EXCEPTION      = 'VT06';
  VT_ERROR_OPEN_FAILED         = 'VT07';
  VT_ERROR_OPEN_MAPPING        = 'VT08';
  VT_ERROR_OPEN_MAPVIEW        = 'VT09';
  VT_ERROR_OPEN_EXCEPTION      = 'VT10';
  VT_ERROR_OPEN_EMPTY          = 'VT11';
  VT_ERROR_GROW_NOT_ANONYMOUS  = 'VT12';
  VT_ERROR_GROW_REMAP          = 'VT13';
  VT_ERROR_FLUSH_FAILED        = 'VT14';
  VT_ERROR_SHARED_NAME_EMPTY   = 'VT15';
  VT_ERROR_SHARED_OPEN_FAILED  = 'VT16';
  VT_ERROR_SHARED_MAPVIEW      = 'VT17';
  VT_ERROR_SHARED_EXCEPTION    = 'VT18';
  VT_ERROR_ALLOC_NAME_EXISTS   = 'VT19';

type

  { TVirtuosoMode }
  TVirtuosoMode = (
    vmAllocate,    // Anonymous page-file-backed, read-write
    vmReadOnly,    // File-backed, read-only (PAGE_READONLY)
    vmReadWrite,   // File-backed, read-write (PAGE_READWRITE), changes persist
    vmCopyOnWrite  // File-backed, private writes (PAGE_WRITECOPY), file untouched
  );

  { TVirtuosoStream }
  TVirtuosoStream = class(TStream)
  private
    FMemory: Pointer;
    FSize: Int64;
    FPosition: Int64;
    FIsReadOnly: Boolean;
    FMREW: TMultiReadExclusiveWriteSynchronizer;
    FThreadSafe: Boolean;
    procedure DoBeginRead();
    procedure DoEndRead();
    procedure DoBeginWrite();
    procedure DoEndWrite();
  protected
    function GetSize(): Int64; override;
  public
    constructor Create(
      const AMemory: Pointer;
      const ASize: Int64;
      const AIsReadOnly: Boolean;
      const AMREW: TMultiReadExclusiveWriteSynchronizer;
      const AThreadSafe: Boolean
    );
    function Read(var ABuffer; ACount: Longint): Longint; override;
    function Write(const ABuffer; ACount: Longint): Longint; override;
    function Seek(const AOffset: Int64; AOrigin: TSeekOrigin): Int64; override;
  end;

  { TVirtuosoEnumerator<T> }
  TVirtuosoEnumerator<T> = class
  private
    FMemory: Pointer;
    FCapacity: UInt64;
    FIndex: Int64;
    FMREW: TMultiReadExclusiveWriteSynchronizer;
    FThreadSafe: Boolean;
    function GetCurrent(): T;
  public
    constructor Create(
      const AMemory: Pointer;
      const ACapacity: UInt64;
      const AMREW: TMultiReadExclusiveWriteSynchronizer;
      const AThreadSafe: Boolean
    );
    destructor Destroy(); override;
    function MoveNext(): Boolean;
    property Current: T read GetCurrent;
  end;

  { TVirtuosoView<T> }
  TVirtuosoView<T> = class
  private
    FBaseMemory: Pointer;  // points to start of this view's region
    FSize: UInt64;         // byte size of the view region
    FPosition: UInt64;
    FIsReadOnly: Boolean;
    FMREW: TMultiReadExclusiveWriteSynchronizer;
    FThreadSafe: Boolean;
    function GetItem(AIndex: UInt64): T;
    procedure SetItem(AIndex: UInt64; AValue: T);
    function GetCapacity(): UInt64;
    function GetIsOpen(): Boolean;
    procedure DoBeginRead();
    procedure DoEndRead();
    procedure DoBeginWrite();
    procedure DoEndWrite();
  public
    constructor Create(
      const ABaseMemory: Pointer;
      const ASize: UInt64;
      const AIsReadOnly: Boolean;
      const AMREW: TMultiReadExclusiveWriteSynchronizer;
      const AThreadSafe: Boolean
    );

    // Stream-style read/write within the view bounds
    function Read(var ABuffer; const ACount: UInt64): UInt64;
    function Write(const ABuffer; const ACount: UInt64): UInt64;

    // Position management
    procedure SetPosition(const AValue: UInt64);
    function Eob(): Boolean;

    // Persistence
    procedure SaveToStream(const AStream: TStream);
    procedure SaveToFile(const AFileName: string);

    // Typed indexed access (relative to view start)
    property Item[AIndex: UInt64]: T read GetItem write SetItem; default;

    property IsOpen: Boolean read GetIsOpen;
    property IsReadOnly: Boolean read FIsReadOnly;
    property Memory: Pointer read FBaseMemory;
    property Size: UInt64 read FSize;
    property Capacity: UInt64 read GetCapacity;
    property Position: UInt64 read FPosition write SetPosition;
  end;

  { TVirtuoso<T> }
  TVirtuoso<T> = class
  private
    // OS handles
    FFileHandle: THandle;
    FMappingHandle: THandle;
    FMemory: Pointer;

    // State
    FSize: UInt64;
    FPosition: UInt64;
    FMode: TVirtuosoMode;
    FFilename: string;
    FMappingName: string;

    // Threading
    FMREW: TMultiReadExclusiveWriteSynchronizer;
    FThreadSafe: Boolean;

    // Shared memory (IPC)
    FIsSharedConsumer: Boolean;
    FIsReadOnlyConsumer: Boolean;

    // Auto-grow (anonymous mode only)
    FAutoGrow: Boolean;
    FGrowFactor: Double;

    // Error state
    FLastError: string;
    FLastErrorCode: string;

    // Private helpers
    procedure DoClear();
    procedure SetError(const ACode: string; const AMessage: string); overload;
    procedure SetError(const ACode: string; const AFormat: string;
      const AArgs: array of const); overload;

    // Property accessors
    function GetItem(AIndex: UInt64): T;
    procedure SetItem(AIndex: UInt64; AValue: T);
    function GetCapacity(): UInt64;
    function GetIsOpen(): Boolean;
    function GetIsReadOnly(): Boolean;
    function GetIsSharedOwner(): Boolean;
    procedure SetPosition(const AValue: UInt64);

    // Internal lock wrappers (respect FThreadSafe)
    procedure DoBeginRead();
    procedure DoEndRead();
    procedure DoBeginWrite();
    procedure DoEndWrite();

    // Internal write with optional auto-grow
    function DoWrite(const ABuffer: Pointer; const ACount: UInt64): UInt64;

    // Ensure writable mode or raise
    procedure CheckWritable();

  public
    constructor Create();
    destructor Destroy(); override;
    function Allocate(const ASize: UInt64;
      const AMappingName: string = ''): Boolean;

    function OpenShared(const AMappingName: string;
      const ASize: UInt64;
      const AReadOnly: Boolean = False): Boolean;

    function Open(const AFilename: string;
      const AMode: TVirtuosoMode = vmReadOnly): Boolean;

    procedure Close();

    procedure BeginRead();
    procedure EndRead();
    procedure BeginWrite();
    procedure EndWrite();

    function Read(var ABuffer; const ACount: UInt64): UInt64; overload;
    function Read(var ABuffer: TBytes;
      const AOffset: UInt64; const ACount: UInt64): UInt64; overload;
    function Write(const ABuffer; const ACount: UInt64): UInt64; overload;
    function Write(const ABuffer: TBytes;
      const AOffset: UInt64; const ACount: UInt64): UInt64; overload;
    function ReadString(): string;
    procedure WriteString(const AValue: string);
    function Seek(const AOffset: Int64;
      const AOrigin: TSeekOrigin): UInt64;
    function Eob(): Boolean;

    procedure SaveToStream(const AStream: TStream);
    procedure SaveToFile(const AFilename: string);
    class function LoadFromFile(const AFilename: string): TVirtuoso<T>;

    function FlushToDisk(): Boolean;

    procedure ZeroMemory();
    procedure CopyFrom(const ASource: Pointer; const ASizeBytes: UInt64);
    procedure Fill(const AValue: T);
    function Contains(const AValue: T): Boolean;
    function IndexOf(const AValue: T): Int64;

    function CreateStream(): TStream;
    function CreateView(const AOffset: UInt64;
      const ACount: UInt64): TVirtuosoView<T>;
    function Grow(const ANewSize: UInt64): Boolean;
    function GetEnumerator(): TVirtuosoEnumerator<T>;

    function HasError(): Boolean;
    procedure ClearError();

    property Item[AIndex: UInt64]: T read GetItem write SetItem; default;
    property Capacity: UInt64 read GetCapacity;
    property Memory: Pointer read FMemory;
    property Size: UInt64 read FSize;
    property Position: UInt64 read FPosition write SetPosition;
    property IsOpen: Boolean read GetIsOpen;
    property IsReadOnly: Boolean read GetIsReadOnly;
    property IsSharedOwner: Boolean read GetIsSharedOwner;
    property MappingMode: TVirtuosoMode read FMode;
    property Filename: string read FFilename;
    property MappingHandle: THandle read FMappingHandle;
    property MappingName: string read FMappingName;
    property ThreadSafe: Boolean read FThreadSafe write FThreadSafe;
    property AutoGrow: Boolean read FAutoGrow write FAutoGrow;
    property GrowFactor: Double read FGrowFactor write FGrowFactor;
    property LastError: string read FLastError;
    property LastErrorCode: string read FLastErrorCode;
  end;

implementation

{ TVirtuosoStream }
constructor TVirtuosoStream.Create(
  const AMemory: Pointer;
  const ASize: Int64;
  const AIsReadOnly: Boolean;
  const AMREW: TMultiReadExclusiveWriteSynchronizer;
  const AThreadSafe: Boolean);
begin
  inherited Create();
  FMemory := AMemory;
  FSize := ASize;
  FPosition := 0;
  FIsReadOnly := AIsReadOnly;
  FMREW := AMREW;
  FThreadSafe := AThreadSafe;
end;

procedure TVirtuosoStream.DoBeginRead();
begin
  if FThreadSafe then
    FMREW.BeginRead();
end;

procedure TVirtuosoStream.DoEndRead();
begin
  if FThreadSafe then
    FMREW.EndRead();
end;

procedure TVirtuosoStream.DoBeginWrite();
begin
  if FThreadSafe then
    FMREW.BeginWrite();
end;

procedure TVirtuosoStream.DoEndWrite();
begin
  if FThreadSafe then
    FMREW.EndWrite();
end;

function TVirtuosoStream.GetSize(): Int64;
begin
  Result := FSize;
end;

function TVirtuosoStream.Read(var ABuffer; ACount: Longint): Longint;
var
  LAvailable: Int64;
begin
  DoBeginRead();
  try
    LAvailable := FSize - FPosition;
    if ACount > LAvailable then
      ACount := Longint(LAvailable);
    if ACount <= 0 then
      Exit(0);
    CopyMemory(@ABuffer,
      Pointer(UIntPtr(FMemory) + UIntPtr(FPosition)), ACount);
    Inc(FPosition, ACount);
    Result := ACount;
  finally
    DoEndRead();
  end;
end;

function TVirtuosoStream.Write(const ABuffer; ACount: Longint): Longint;
var
  LAvailable: Int64;
begin
  if FIsReadOnly then
    raise EInvalidOperation.Create('Cannot write to a read-only stream');

  DoBeginWrite();
  try
    LAvailable := FSize - FPosition;
    if ACount > LAvailable then
      ACount := Longint(LAvailable);
    if ACount <= 0 then
      Exit(0);
    CopyMemory(
      Pointer(UIntPtr(FMemory) + UIntPtr(FPosition)), @ABuffer, ACount);
    Inc(FPosition, ACount);
    Result := ACount;
  finally
    DoEndWrite();
  end;
end;

function TVirtuosoStream.Seek(const AOffset: Int64;
  AOrigin: TSeekOrigin): Int64;
var
  LNewPos: Int64;
begin
  DoBeginWrite();
  try
    if AOrigin = soBeginning then
      LNewPos := AOffset
    else if AOrigin = soCurrent then
      LNewPos := FPosition + AOffset
    else // soEnd
      LNewPos := FSize + AOffset;

    if (LNewPos < 0) or (LNewPos > FSize) then
      raise EArgumentOutOfRangeException.Create(
        'Stream seek position out of bounds');
    FPosition := LNewPos;
    Result := FPosition;
  finally
    DoEndWrite();
  end;
end;

{ TVirtuosoEnumerator<T> }
constructor TVirtuosoEnumerator<T>.Create(
  const AMemory: Pointer;
  const ACapacity: UInt64;
  const AMREW: TMultiReadExclusiveWriteSynchronizer;
  const AThreadSafe: Boolean);
begin
  inherited Create();
  FMemory := AMemory;
  FCapacity := ACapacity;
  FIndex := -1;
  FMREW := AMREW;
  FThreadSafe := AThreadSafe;

  // Acquire read lock for the duration of enumeration
  if FThreadSafe then
    FMREW.BeginRead();
end;

destructor TVirtuosoEnumerator<T>.Destroy();
begin
  // Release read lock held since construction
  if FThreadSafe then
    FMREW.EndRead();
  inherited;
end;

function TVirtuosoEnumerator<T>.MoveNext(): Boolean;
begin
  Inc(FIndex);
  Result := UInt64(FIndex) < FCapacity;
end;

function TVirtuosoEnumerator<T>.GetCurrent(): T;
begin
  CopyMemory(@Result,
    Pointer(UIntPtr(FMemory) + UIntPtr(UInt64(FIndex) * UInt64(SizeOf(T)))),
    SizeOf(T));
end;

{ TVirtuosoView<T> }
constructor TVirtuosoView<T>.Create(
  const ABaseMemory: Pointer;
  const ASize: UInt64;
  const AIsReadOnly: Boolean;
  const AMREW: TMultiReadExclusiveWriteSynchronizer;
  const AThreadSafe: Boolean);
begin
  inherited Create();
  FBaseMemory := ABaseMemory;
  FSize := ASize;
  FPosition := 0;
  FIsReadOnly := AIsReadOnly;
  FMREW := AMREW;
  FThreadSafe := AThreadSafe;
end;

procedure TVirtuosoView<T>.DoBeginRead();
begin
  if FThreadSafe then
    FMREW.BeginRead();
end;

procedure TVirtuosoView<T>.DoEndRead();
begin
  if FThreadSafe then
    FMREW.EndRead();
end;

procedure TVirtuosoView<T>.DoBeginWrite();
begin
  if FThreadSafe then
    FMREW.BeginWrite();
end;

procedure TVirtuosoView<T>.DoEndWrite();
begin
  if FThreadSafe then
    FMREW.EndWrite();
end;

function TVirtuosoView<T>.GetIsOpen(): Boolean;
begin
  Result := FBaseMemory <> nil;
end;

function TVirtuosoView<T>.GetCapacity(): UInt64;
begin
  Result := FSize div UInt64(SizeOf(T));
end;

function TVirtuosoView<T>.GetItem(AIndex: UInt64): T;
begin
  DoBeginRead();
  try
    if AIndex >= GetCapacity() then
      raise EArgumentOutOfRangeException.Create('View index out of bounds');
    CopyMemory(@Result,
      Pointer(UIntPtr(FBaseMemory) + UIntPtr(AIndex * UInt64(SizeOf(T)))),
      SizeOf(T));
  finally
    DoEndRead();
  end;
end;

procedure TVirtuosoView<T>.SetItem(AIndex: UInt64; AValue: T);
begin
  if FIsReadOnly then
    raise EInvalidOperation.Create('Cannot write to a read-only view');

  DoBeginWrite();
  try
    if AIndex >= GetCapacity() then
      raise EArgumentOutOfRangeException.Create('View index out of bounds');
    CopyMemory(
      Pointer(UIntPtr(FBaseMemory) + UIntPtr(AIndex * UInt64(SizeOf(T)))),
      @AValue, SizeOf(T));
  finally
    DoEndWrite();
  end;
end;

procedure TVirtuosoView<T>.SetPosition(const AValue: UInt64);
begin
  DoBeginWrite();
  try
    if AValue > FSize then
      raise EArgumentOutOfRangeException.Create(
        'View position out of bounds');
    FPosition := AValue;
  finally
    DoEndWrite();
  end;
end;

function TVirtuosoView<T>.Read(var ABuffer; const ACount: UInt64): UInt64;
var
  LCount: UInt64;
begin
  DoBeginRead();
  try
    LCount := ACount;
    if FPosition + LCount > FSize then
      LCount := FSize - FPosition;
    if LCount > 0 then
      CopyMemory(@ABuffer,
        Pointer(UIntPtr(FBaseMemory) + UIntPtr(FPosition)), LCount);
    Inc(FPosition, LCount);
    Result := LCount;
  finally
    DoEndRead();
  end;
end;

function TVirtuosoView<T>.Write(const ABuffer;
  const ACount: UInt64): UInt64;
begin
  if FIsReadOnly then
    raise EInvalidOperation.Create('Cannot write to a read-only view');

  DoBeginWrite();
  try
    if FPosition + ACount > FSize then
      Exit(0);
    CopyMemory(
      Pointer(UIntPtr(FBaseMemory) + UIntPtr(FPosition)), @ABuffer, ACount);
    Inc(FPosition, ACount);
    Result := ACount;
  finally
    DoEndWrite();
  end;
end;

function TVirtuosoView<T>.Eob(): Boolean;
begin
  Result := FPosition >= FSize;
end;

procedure TVirtuosoView<T>.SaveToStream(const AStream: TStream);
begin
  DoBeginRead();
  try
    if FSize > 0 then
      AStream.WriteBuffer(FBaseMemory^, FSize);
  finally
    DoEndRead();
  end;
end;

procedure TVirtuosoView<T>.SaveToFile(const AFileName: string);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFileName, fmCreate);
  try
    SaveToStream(LStream);
  finally
    LStream.Free();
  end;
end;

{ TVirtuoso<T> }
constructor TVirtuoso<T>.Create();
begin
  inherited Create();
  FMREW := TMultiReadExclusiveWriteSynchronizer.Create();
  FFileHandle := INVALID_HANDLE_VALUE;
  FMappingHandle := 0;
  FMemory := nil;
  FSize := 0;
  FPosition := 0;
  FMode := vmAllocate;
  FFilename := '';
  FMappingName := '';
  FThreadSafe := True;
  FAutoGrow := False;
  FGrowFactor := 2.0;
  FIsSharedConsumer := False;
  FIsReadOnlyConsumer := False;
  FLastError := '';
  FLastErrorCode := '';
end;

destructor TVirtuoso<T>.Destroy();
begin
  DoClear();
  FMREW.Free();
  inherited;
end;

procedure TVirtuoso<T>.SetError(const ACode: string;
  const AMessage: string);
begin
  FLastErrorCode := ACode;
  FLastError := AMessage;
end;

procedure TVirtuoso<T>.SetError(const ACode: string;
  const AFormat: string; const AArgs: array of const);
begin
  FLastErrorCode := ACode;
  FLastError := Format(AFormat, AArgs);
end;

function TVirtuoso<T>.HasError(): Boolean;
begin
  Result := FLastErrorCode <> '';
end;

procedure TVirtuoso<T>.ClearError();
begin
  FLastError := '';
  FLastErrorCode := '';
end;

procedure TVirtuoso<T>.CheckWritable();
begin
  if GetIsReadOnly() then
    raise EInvalidOperation.Create(
      'Cannot write in read-only mode');
end;

procedure TVirtuoso<T>.DoBeginRead();
begin
  if FThreadSafe then
    FMREW.BeginRead();
end;

procedure TVirtuoso<T>.DoEndRead();
begin
  if FThreadSafe then
    FMREW.EndRead();
end;

procedure TVirtuoso<T>.DoBeginWrite();
begin
  if FThreadSafe then
    FMREW.BeginWrite();
end;

procedure TVirtuoso<T>.DoEndWrite();
begin
  if FThreadSafe then
    FMREW.EndWrite();
end;

procedure TVirtuoso<T>.BeginRead();
begin
  DoBeginRead();
end;

procedure TVirtuoso<T>.EndRead();
begin
  DoEndRead();
end;

procedure TVirtuoso<T>.BeginWrite();
begin
  DoBeginWrite();
end;

procedure TVirtuoso<T>.EndWrite();
begin
  DoEndWrite();
end;

procedure TVirtuoso<T>.DoClear();
begin
  if FMemory <> nil then
    UnmapViewOfFile(FMemory);
  if FMappingHandle <> 0 then
    CloseHandle(FMappingHandle);
  if FFileHandle <> INVALID_HANDLE_VALUE then
    CloseHandle(FFileHandle);

  FMemory := nil;
  FMappingHandle := 0;
  FFileHandle := INVALID_HANDLE_VALUE;
  FSize := 0;
  FPosition := 0;
  FFilename := '';
  FMappingName := '';
  FIsSharedConsumer := False;
  FIsReadOnlyConsumer := False;
end;

procedure TVirtuoso<T>.Close();
begin
  DoBeginWrite();
  try
    DoClear();
  finally
    DoEndWrite();
  end;
end;

function TVirtuoso<T>.GetIsOpen(): Boolean;
begin
  Result := FMemory <> nil;
end;

function TVirtuoso<T>.GetIsReadOnly(): Boolean;
begin
  Result := (FMode = vmReadOnly) or FIsReadOnlyConsumer;
end;

function TVirtuoso<T>.GetIsSharedOwner(): Boolean;
begin
  Result := GetIsOpen() and (not FIsSharedConsumer);
end;

function TVirtuoso<T>.GetCapacity(): UInt64;
begin
  Result := FSize div UInt64(SizeOf(T));
end;

procedure TVirtuoso<T>.SetPosition(const AValue: UInt64);
begin
  DoBeginWrite();
  try
    if AValue > FSize then
      raise EArgumentOutOfRangeException.Create('Position out of bounds');
    FPosition := AValue;
  finally
    DoEndWrite();
  end;
end;

function TVirtuoso<T>.GetItem(AIndex: UInt64): T;
begin
  DoBeginRead();
  try
    if AIndex >= GetCapacity() then
      raise EArgumentOutOfRangeException.Create('Index out of bounds');
    CopyMemory(@Result,
      Pointer(UIntPtr(FMemory) + UIntPtr(AIndex * UInt64(SizeOf(T)))),
      SizeOf(T));
  finally
    DoEndRead();
  end;
end;

procedure TVirtuoso<T>.SetItem(AIndex: UInt64; AValue: T);
begin
  CheckWritable();
  DoBeginWrite();
  try
    if AIndex >= GetCapacity() then
      raise EArgumentOutOfRangeException.Create('Index out of bounds');
    CopyMemory(
      Pointer(UIntPtr(FMemory) + UIntPtr(AIndex * UInt64(SizeOf(T)))),
      @AValue, SizeOf(T));
  finally
    DoEndWrite();
  end;
end;

function TVirtuoso<T>.Allocate(const ASize: UInt64;
  const AMappingName: string = ''): Boolean;
var
  LSizeHigh: DWORD;
  LSizeLow: DWORD;
  LTotalBytes: UInt64;
begin
  Result := False;
  ClearError();

  if ASize = 0 then
  begin
    SetError(VT_ERROR_ALLOC_SIZE_ZERO,
      'Cannot allocate a zero-size buffer');
    Exit;
  end;

  // Release any prior mapping
  Close();

  LTotalBytes := UInt64(SizeOf(T)) * ASize;
  LSizeLow := DWORD(LTotalBytes and $FFFFFFFF);
  LSizeHigh := DWORD(LTotalBytes shr 32);

  // Use caller-supplied name or generate a GUID-based name
  if AMappingName <> '' then
    FMappingName := AMappingName
  else
    FMappingName := TPath.GetGUIDFileName();

  try
    FMappingHandle := CreateFileMapping(INVALID_HANDLE_VALUE, nil,
      PAGE_READWRITE, LSizeHigh, LSizeLow, PChar(FMappingName));
    if FMappingHandle = 0 then
    begin
      SetError(VT_ERROR_ALLOC_MAPPING,
        'CreateFileMapping failed (error %d)', [GetLastError()]);
      Exit;
    end;

    // If the caller supplied a custom name, reject if the mapping
    // already existed — the producer should own the name exclusively
    if (AMappingName <> '') and (GetLastError() = ERROR_ALREADY_EXISTS) then
    begin
      CloseHandle(FMappingHandle);
      FMappingHandle := 0;
      SetError(VT_ERROR_ALLOC_NAME_EXISTS,
        'Mapping name "%s" already exists', [AMappingName]);
      Exit;
    end;

    FMemory := MapViewOfFile(FMappingHandle, FILE_MAP_ALL_ACCESS, 0, 0, 0);
    if FMemory = nil then
    begin
      SetError(VT_ERROR_ALLOC_MAPVIEW,
        'MapViewOfFile failed (error %d)', [GetLastError()]);
      CloseHandle(FMappingHandle);
      FMappingHandle := 0;
      Exit;
    end;
  except
    on E: Exception do
    begin
      SetError(VT_ERROR_ALLOC_EXCEPTION,
        'Allocate exception: %s', [E.Message]);
      DoClear();
      Exit;
    end;
  end;

  FSize := LTotalBytes;
  FPosition := 0;
  FMode := vmAllocate;
  FFilename := '';
  FFileHandle := INVALID_HANDLE_VALUE;
  FIsSharedConsumer := False;
  Result := True;
end;

function TVirtuoso<T>.OpenShared(const AMappingName: string;
  const ASize: UInt64;
  const AReadOnly: Boolean = False): Boolean;
var
  LMapAccess: DWORD;
  LTotalBytes: UInt64;
begin
  Result := False;
  ClearError();

  if AMappingName = '' then
  begin
    SetError(VT_ERROR_SHARED_NAME_EMPTY,
      'OpenShared: mapping name must not be empty');
    Exit;
  end;

  // Release any prior mapping
  Close();

  LTotalBytes := UInt64(SizeOf(T)) * ASize;

  if AReadOnly then
    LMapAccess := FILE_MAP_READ
  else
    LMapAccess := FILE_MAP_ALL_ACCESS;

  try
    FMappingHandle := OpenFileMapping(LMapAccess, False,
      PChar(AMappingName));
    if FMappingHandle = 0 then
    begin
      SetError(VT_ERROR_SHARED_OPEN_FAILED,
        'OpenFileMapping failed for "%s" (error %d)',
        [AMappingName, GetLastError()]);
      Exit;
    end;

    FMemory := MapViewOfFile(FMappingHandle, LMapAccess, 0, 0, 0);
    if FMemory = nil then
    begin
      SetError(VT_ERROR_SHARED_MAPVIEW,
        'MapViewOfFile failed for "%s" (error %d)',
        [AMappingName, GetLastError()]);
      CloseHandle(FMappingHandle);
      FMappingHandle := 0;
      Exit;
    end;
  except
    on E: Exception do
    begin
      SetError(VT_ERROR_SHARED_EXCEPTION,
        'OpenShared exception for "%s": %s', [AMappingName, E.Message]);
      DoClear();
      Exit;
    end;
  end;

  FSize := LTotalBytes;
  FPosition := 0;
  FMode := vmAllocate;
  FFilename := '';
  FMappingName := AMappingName;
  FFileHandle := INVALID_HANDLE_VALUE;
  FIsSharedConsumer := True;
  FIsReadOnlyConsumer := AReadOnly;
  Result := True;
end;

function TVirtuoso<T>.Open(const AFilename: string;
  const AMode: TVirtuosoMode): Boolean;
var
  LFileSizeHigh: DWORD;
  LFileSizeLow: DWORD;
  LTotalSize: UInt64;
  LDesiredAccess: DWORD;
  LPageProtect: DWORD;
  LMapAccess: DWORD;
begin
  Result := False;
  ClearError();

  if AMode = vmAllocate then
  begin
    // vmAllocate is not valid for Open; use Allocate() instead.
    SetError(VT_ERROR_OPEN_FAILED,
      'Use Allocate() for anonymous buffers, not Open()');
    Exit;
  end;

  // Release any prior mapping
  Close();

  // Determine OS flags based on mode
  if AMode = vmReadOnly then
  begin
    LDesiredAccess := GENERIC_READ;
    LPageProtect := PAGE_READONLY;
    LMapAccess := FILE_MAP_READ;
  end
  else if AMode = vmReadWrite then
  begin
    LDesiredAccess := GENERIC_READ or GENERIC_WRITE;
    LPageProtect := PAGE_READWRITE;
    LMapAccess := FILE_MAP_ALL_ACCESS;
  end
  else // vmCopyOnWrite
  begin
    LDesiredAccess := GENERIC_READ;
    LPageProtect := PAGE_WRITECOPY;
    LMapAccess := FILE_MAP_COPY;
  end;

  try
    FFileHandle := CreateFile(PChar(AFilename),
      LDesiredAccess, FILE_SHARE_READ, nil,
      OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    if FFileHandle = INVALID_HANDLE_VALUE then
    begin
      SetError(VT_ERROR_OPEN_FAILED,
        'Cannot open file "%s" (error %d)',
        [AFilename, GetLastError()]);
      Exit;
    end;

    LFileSizeLow := GetFileSize(FFileHandle, @LFileSizeHigh);
    LTotalSize := (UInt64(LFileSizeHigh) shl 32) or UInt64(LFileSizeLow);

    if LTotalSize = 0 then
    begin
      SetError(VT_ERROR_OPEN_EMPTY,
        'File "%s" is empty — cannot memory-map', [AFilename]);
      CloseHandle(FFileHandle);
      FFileHandle := INVALID_HANDLE_VALUE;
      Exit;
    end;

    FMappingHandle := CreateFileMapping(FFileHandle, nil,
      LPageProtect, 0, 0, nil);
    if FMappingHandle = 0 then
    begin
      SetError(VT_ERROR_OPEN_MAPPING,
        'CreateFileMapping failed for "%s" (error %d)',
        [AFilename, GetLastError()]);
      CloseHandle(FFileHandle);
      FFileHandle := INVALID_HANDLE_VALUE;
      Exit;
    end;

    FMemory := MapViewOfFile(FMappingHandle, LMapAccess, 0, 0, 0);
    if FMemory = nil then
    begin
      SetError(VT_ERROR_OPEN_MAPVIEW,
        'MapViewOfFile failed for "%s" (error %d)',
        [AFilename, GetLastError()]);
      CloseHandle(FMappingHandle);
      FMappingHandle := 0;
      CloseHandle(FFileHandle);
      FFileHandle := INVALID_HANDLE_VALUE;
      Exit;
    end;
  except
    on E: Exception do
    begin
      SetError(VT_ERROR_OPEN_EXCEPTION,
        'Open exception for "%s": %s', [AFilename, E.Message]);
      DoClear();
      Exit;
    end;
  end;

  FFilename := AFilename;
  FSize := LTotalSize;
  FPosition := 0;
  FMode := AMode;
  FMappingName := '';
  Result := True;
end;

function TVirtuoso<T>.Read(var ABuffer; const ACount: UInt64): UInt64;
var
  LCount: UInt64;
begin
  DoBeginRead();
  try
    LCount := ACount;
    if FPosition + LCount > FSize then
      LCount := FSize - FPosition;
    if LCount > 0 then
      CopyMemory(@ABuffer,
        Pointer(UIntPtr(FMemory) + UIntPtr(FPosition)), LCount);
    Inc(FPosition, LCount);
    Result := LCount;
  finally
    DoEndRead();
  end;
end;

function TVirtuoso<T>.Read(var ABuffer: TBytes;
  const AOffset: UInt64; const ACount: UInt64): UInt64;
var
  LCount: UInt64;
begin
  DoBeginRead();
  try
    if (AOffset + ACount > UInt64(Length(ABuffer))) then
      raise EArgumentOutOfRangeException.Create(
        'Buffer overflow in Read');

    LCount := ACount;
    if FPosition + LCount > FSize then
      LCount := FSize - FPosition;
    if LCount > 0 then
      CopyMemory(@ABuffer[AOffset],
        Pointer(UIntPtr(FMemory) + UIntPtr(FPosition)), LCount);
    Inc(FPosition, LCount);
    Result := LCount;
  finally
    DoEndRead();
  end;
end;

function TVirtuoso<T>.DoWrite(const ABuffer: Pointer;
  const ACount: UInt64): UInt64;
var
  LNeeded: UInt64;
  LNewSize: UInt64;
begin
  // Check if we need to auto-grow (anonymous mode only)
  LNeeded := FPosition + ACount;
  if LNeeded > FSize then
  begin
    if FAutoGrow and (FMode = vmAllocate) then
    begin
      // Grow to at least the needed size, or by GrowFactor
      LNewSize := FSize;
      if LNewSize = 0 then
        LNewSize := UInt64(SizeOf(T));
      while LNewSize < LNeeded do
        LNewSize := UInt64(Trunc(Double(LNewSize) * FGrowFactor));
      // Convert bytes to element count for Grow
      if not Grow(LNewSize div UInt64(SizeOf(T))) then
        Exit(0);
    end
    else
      Exit(0);
  end;

  CopyMemory(
    Pointer(UIntPtr(FMemory) + UIntPtr(FPosition)), ABuffer, ACount);
  Inc(FPosition, ACount);
  Result := ACount;
end;

function TVirtuoso<T>.Write(const ABuffer;
  const ACount: UInt64): UInt64;
begin
  CheckWritable();
  DoBeginWrite();
  try
    Result := DoWrite(@ABuffer, ACount);
  finally
    DoEndWrite();
  end;
end;

function TVirtuoso<T>.Write(const ABuffer: TBytes;
  const AOffset: UInt64; const ACount: UInt64): UInt64;
begin
  CheckWritable();
  DoBeginWrite();
  try
    if (AOffset + ACount > UInt64(Length(ABuffer))) then
      raise EArgumentOutOfRangeException.Create(
        'Buffer overflow in Write');
    Result := DoWrite(@ABuffer[AOffset], ACount);
  finally
    DoEndWrite();
  end;
end;

function TVirtuoso<T>.ReadString(): string;
var
  LLen: UInt64;
begin
  Read(LLen, SizeOf(LLen));
  SetLength(Result, LLen);
  if LLen > 0 then
    Read(Result[1], LLen * UInt64(SizeOf(Char)));
end;

procedure TVirtuoso<T>.WriteString(const AValue: string);
var
  LLength: UInt64;
begin
  CheckWritable();
  DoBeginWrite();
  try
    LLength := Length(AValue);
    DoWrite(@LLength, SizeOf(LLength));
    if LLength > 0 then
      DoWrite(PChar(AValue), LLength * UInt64(SizeOf(Char)));
  finally
    DoEndWrite();
  end;
end;

function TVirtuoso<T>.Seek(const AOffset: Int64;
  const AOrigin: TSeekOrigin): UInt64;
var
  LNewPos: Int64;
begin
  DoBeginWrite();
  try
    if AOrigin = soBeginning then
      LNewPos := AOffset
    else if AOrigin = soCurrent then
      LNewPos := Int64(FPosition) + AOffset
    else // soEnd
      LNewPos := Int64(FSize) + AOffset;

    if (LNewPos < 0) or (UInt64(LNewPos) > FSize) then
      raise EArgumentOutOfRangeException.Create(
        'Seek position out of bounds');
    FPosition := UInt64(LNewPos);
    Result := FPosition;
  finally
    DoEndWrite();
  end;
end;

function TVirtuoso<T>.Eob(): Boolean;
begin
  Result := FPosition >= FSize;
end;

procedure TVirtuoso<T>.SaveToStream(const AStream: TStream);
begin
  DoBeginRead();
  try
    if FSize > 0 then
      AStream.WriteBuffer(FMemory^, FSize);
  finally
    DoEndRead();
  end;
end;

procedure TVirtuoso<T>.SaveToFile(const AFilename: string);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(AFilename, fmCreate);
  try
    SaveToStream(LStream);
  finally
    LStream.Free();
  end;
end;

class function TVirtuoso<T>.LoadFromFile(
  const AFilename: string): TVirtuoso<T>;
var
  LFileStream: TFileStream;
  LFileSize: Int64;
  LElements: UInt64;
begin
  Result := TVirtuoso<T>.Create();
  try
    LFileStream := TFileStream.Create(AFilename,
      fmOpenRead or fmShareDenyWrite);
    try
      LFileSize := LFileStream.Size;
      if LFileSize mod SizeOf(T) <> 0 then
      begin
        Result.SetError(VT_ERROR_LOAD_ALIGNMENT,
          'File size (%d) is not aligned to element size (%d)',
          [LFileSize, SizeOf(T)]);
        Exit;
      end;

      LElements := LFileSize div SizeOf(T);
      if not Result.Allocate(LElements) then
        Exit;

      LFileStream.ReadBuffer(Result.FMemory^, LFileSize);
      Result.FPosition := 0;
    finally
      LFileStream.Free();
    end;
  except
    on E: Exception do
      Result.SetError(VT_ERROR_LOAD_EXCEPTION,
        'LoadFromFile exception for "%s": %s', [AFilename, E.Message]);
  end;
end;

function TVirtuoso<T>.FlushToDisk(): Boolean;
begin
  Result := True;

  // Only meaningful for read-write file-backed mappings
  if FMode <> vmReadWrite then
    Exit;

  DoBeginRead();
  try
    if (FMemory <> nil) and (FSize > 0) then
    begin
      if not FlushViewOfFile(FMemory, 0) then
      begin
        SetError(VT_ERROR_FLUSH_FAILED,
          'FlushViewOfFile failed (error %d)', [GetLastError()]);
        Result := False;
      end;
    end;
  finally
    DoEndRead();
  end;
end;

procedure TVirtuoso<T>.ZeroMemory();
begin
  CheckWritable();
  DoBeginWrite();
  try
    FillChar(FMemory^, FSize, 0);
  finally
    DoEndWrite();
  end;
end;

procedure TVirtuoso<T>.CopyFrom(const ASource: Pointer;
  const ASizeBytes: UInt64);
begin
  CheckWritable();
  DoBeginWrite();
  try
    if ASizeBytes > FSize then
      raise EArgumentOutOfRangeException.Create(
        'Source size exceeds buffer capacity');
    CopyMemory(FMemory, ASource, ASizeBytes);
  finally
    DoEndWrite();
  end;
end;

procedure TVirtuoso<T>.Fill(const AValue: T);
var
  LIndex: UInt64;
  LCap: UInt64;
  LPtr: Pointer;
begin
  CheckWritable();
  DoBeginWrite();
  try
    LCap := GetCapacity();
    LIndex := 0;
    while LIndex < LCap do
    begin
      LPtr := Pointer(UIntPtr(FMemory) +
        UIntPtr(LIndex * UInt64(SizeOf(T))));
      CopyMemory(LPtr, @AValue, SizeOf(T));
      Inc(LIndex);
    end;
  finally
    DoEndWrite();
  end;
end;

function TVirtuoso<T>.Contains(const AValue: T): Boolean;
begin
  Result := IndexOf(AValue) >= 0;
end;

function TVirtuoso<T>.IndexOf(const AValue: T): Int64;
var
  LIndex: UInt64;
  LCap: UInt64;
  LPtr: Pointer;
begin
  Result := -1;
  DoBeginRead();
  try
    LCap := GetCapacity();
    LIndex := 0;
    while LIndex < LCap do
    begin
      LPtr := Pointer(UIntPtr(FMemory) +
        UIntPtr(LIndex * UInt64(SizeOf(T))));
      if CompareMem(LPtr, @AValue, SizeOf(T)) then
      begin
        Result := Int64(LIndex);
        Exit;
      end;
      Inc(LIndex);
    end;
  finally
    DoEndRead();
  end;
end;

function TVirtuoso<T>.CreateStream(): TStream;
begin
  Result := TVirtuosoStream.Create(
    FMemory, Int64(FSize), GetIsReadOnly(), FMREW, FThreadSafe);
end;

function TVirtuoso<T>.CreateView(const AOffset: UInt64;
  const ACount: UInt64): TVirtuosoView<T>;
var
  LByteOffset: UInt64;
  LByteSize: UInt64;
begin
  LByteOffset := AOffset * UInt64(SizeOf(T));
  LByteSize := ACount * UInt64(SizeOf(T));

  if LByteOffset + LByteSize > FSize then
    raise EArgumentOutOfRangeException.Create(
      'View range exceeds buffer bounds');

  Result := TVirtuosoView<T>.Create(
    Pointer(UIntPtr(FMemory) + UIntPtr(LByteOffset)),
    LByteSize, GetIsReadOnly(), FMREW, FThreadSafe);
end;

function TVirtuoso<T>.Grow(const ANewSize: UInt64): Boolean;
var
  LNewTotalBytes: UInt64;
  LOldMemory: Pointer;
  LOldSize: UInt64;
  LOldHandle: THandle;
  LSizeHigh: DWORD;
  LSizeLow: DWORD;
  LNewMappingHandle: THandle;
  LNewMemory: Pointer;
  LNewName: string;
begin
  Result := False;
  ClearError();

  if FMode <> vmAllocate then
  begin
    SetError(VT_ERROR_GROW_NOT_ANONYMOUS,
      'Grow is only valid for anonymous (vmAllocate) buffers');
    Exit;
  end;

  if FIsSharedConsumer then
  begin
    SetError(VT_ERROR_GROW_NOT_ANONYMOUS,
      'Grow is not valid for shared consumer mappings');
    Exit;
  end;

  LNewTotalBytes := ANewSize * UInt64(SizeOf(T));
  if LNewTotalBytes <= FSize then
  begin
    // Already big enough — no-op success
    Result := True;
    Exit;
  end;

  // Must hold exclusive lock during the remap
  DoBeginWrite();
  try
    LOldMemory := FMemory;
    LOldSize := FSize;
    LOldHandle := FMappingHandle;

    LSizeLow := DWORD(LNewTotalBytes and $FFFFFFFF);
    LSizeHigh := DWORD(LNewTotalBytes shr 32);
    LNewName := TPath.GetGUIDFileName();

    try
      LNewMappingHandle := CreateFileMapping(INVALID_HANDLE_VALUE,
        nil, PAGE_READWRITE, LSizeHigh, LSizeLow, PChar(LNewName));
      if LNewMappingHandle = 0 then
      begin
        SetError(VT_ERROR_GROW_REMAP,
          'Grow: CreateFileMapping failed (error %d)',
          [GetLastError()]);
        Exit;
      end;

      LNewMemory := MapViewOfFile(LNewMappingHandle,
        FILE_MAP_ALL_ACCESS, 0, 0, 0);
      if LNewMemory = nil then
      begin
        SetError(VT_ERROR_GROW_REMAP,
          'Grow: MapViewOfFile failed (error %d)',
          [GetLastError()]);
        CloseHandle(LNewMappingHandle);
        Exit;
      end;

      // Copy old data into the new mapping
      if (LOldMemory <> nil) and (LOldSize > 0) then
        CopyMemory(LNewMemory, LOldMemory, LOldSize);

      // Release old mapping
      if LOldMemory <> nil then
        UnmapViewOfFile(LOldMemory);
      if LOldHandle <> 0 then
        CloseHandle(LOldHandle);

      // Swap in the new mapping
      FMemory := LNewMemory;
      FMappingHandle := LNewMappingHandle;
      FMappingName := LNewName;
      FSize := LNewTotalBytes;
      // Position is preserved
      Result := True;
    except
      on E: Exception do
        SetError(VT_ERROR_GROW_REMAP,
          'Grow exception: %s', [E.Message]);
    end;
  finally
    DoEndWrite();
  end;
end;

function TVirtuoso<T>.GetEnumerator(): TVirtuosoEnumerator<T>;
begin
  Result := TVirtuosoEnumerator<T>.Create(
    FMemory, GetCapacity(), FMREW, FThreadSafe);
end;

end.
