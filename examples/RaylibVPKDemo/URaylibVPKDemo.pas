unit URaylibVPKDemo;

interface

procedure RunDemo();

implementation

uses
  System.SysUtils,
  System.IOUtils,
  raylib,
  Virtuoso,
  Virtuoso.VFS;

procedure Pause();
begin
  Write('Press ENTER to continue...');
  ReadLn;
  WriteLn;
end;

function GetVPKPath(): string;
begin
  Result := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), 'RaylibVPKDemo.vpk');
end;

function GetResPath(): string;
begin
  Result := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)), '..\examples\RaylibVPKDemo\res');
end;

procedure BuildVPK();
var
  LResPath: string;
  LVPKPath: string;
begin
  LResPath := GetResPath();
  LVPKPath := GetVPKPath();

  WriteLn('Building VPK archive...');
  WriteLn(Format('  Source: %s', [LResPath]));
  WriteLn(Format('  Output: %s', [LVPKPath]));
  WriteLn;

  if not TVirtuosoVFS.PackDirectory(LResPath, LVPKPath,
    procedure(const AInfo: TVFSPackInfo; var ACancel: Boolean; const AUserData: Pointer)
    begin
      case AInfo.Status of
        vpsStarting:
          WriteLn(Format('  Packing %d files...', [AInfo.FileCount]));
        vpsFileBegin:
          WriteLn(Format('  [%d/%d] %s', [AInfo.FileIndex, AInfo.FileCount, AInfo.EntryPath]));
        vpsCompleted:
          WriteLn(Format('  Done (%d bytes)', [AInfo.TotalBytes]));
        vpsError:
          WriteLn(Format('  ERROR: %s', [AInfo.ErrorMessage]));
      end;
    end
  ) then
  begin
    WriteLn('ERROR: Failed to build VPK archive.');
    Exit;
  end;

  WriteLn;
end;

procedure Demo();
var
  LVFS: TVirtuosoVFS;
  LImageView: TVirtuosoView<Byte>;
  LMusicView: TVirtuosoView<Byte>;
  LImage: Image;
  LTexture: Texture2D;
  LMusic: Music;
  LTexX: Integer;
  LTexY: Integer;
begin
  // Open the VPK archive
  LVFS := TVirtuosoVFS.Create();
  try
    if not LVFS.Open(GetVPKPath()) then
    begin
      WriteLn('ERROR: Failed to open VPK archive.');
      Exit;
    end;

    WriteLn(Format('VPK opened: %d entries', [LVFS.EntryCount()]));

    // Decode image from VPK (CPU-side, no window needed yet)
    LImageView := LVFS.OpenFile('images/virtuoso.png');
    try
      LImage := LoadImageFromMemory('.png', LImageView.Memory, Integer(LImageView.Size));
    finally
      LImageView.Free();
    end;

    // Init window and audio first — required before loading GPU/audio resources
    InitWindow(1280, 640, 'Virtuoso VPK Demo - Raylib from Memory');
    SetTargetFPS(60);
    InitAudioDevice();

    // Music view must stay alive for streaming
    LMusicView := LVFS.OpenFile('music/song01.ogg');
    try
      LMusic := LoadMusicStreamFromMemory('.ogg', LMusicView.Memory, Integer(LMusicView.Size));

      // Upload texture to GPU
      LTexture := LoadTextureFromImage(LImage);
      UnloadImage(LImage);

      // Center the texture
      LTexX := (GetScreenWidth() - LTexture.width) div 2;
      LTexY := (GetScreenHeight() - LTexture.height) div 2;

      // Start music
      PlayMusicStream(LMusic);

      // Game loop
      while not WindowShouldClose() do
      begin
        UpdateMusicStream(LMusic);

        BeginDrawing();
          ClearBackground(RAYWHITE);
          DrawTexture(LTexture, LTexX, LTexY, WHITE);
          DrawText('Texture and music loaded from VPK!', 10, 10, 20, DARKGRAY);
          DrawFPS(10, GetScreenHeight() - 30);
        EndDrawing();
      end;

      // Cleanup
      StopMusicStream(LMusic);
      UnloadTexture(LTexture);
      UnloadMusicStream(LMusic);
    finally
      LMusicView.Free();
    end;

    CloseAudioDevice();
    CloseWindow();
  finally
    LVFS.Free();
  end;
end;

procedure RunDemo();
begin
  try
    // Build VPK if it doesn't exist
    if not TFile.Exists(GetVPKPath()) then
      BuildVPK();

    Demo();
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
