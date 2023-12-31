unit GameViewPlay;

interface

uses Classes,
  CastleComponentSerialize, CastleUIControls, CastleControls, CastleNotifications,
  CastleKeysMouse, CastleViewport, CastleScene, CastleVectors, CastleCameras,
  CastleTransform, GameEnemy, CastleSoundEngine, X3DNodes, X3DFields,
  CastleRenderOptions;

type
  { Передвижение в четырех направлениях, по часовой стрелке }
  TDirection = (dirNorth, dirEast, dirSouth, dirWest);

const
  { Конвертирование TDirection в вектор MainViewport.Camera.Direction. }
  DirectionVector: array [TDirection] of TVector3 = (
    (X: 0; Y: 0; Z: -1),
    (X: 1; Y: 0; Z: 0),
    (X: 0; Y: 0; Z: 1),
    (X: -1; Y: 0; Z: 0)
    );

  DirectionName: array [TDirection] of string = (
    'Север',
    'Восток',
    'Юг',
    'Запад'
    );

  { Время в секундах для поворота и передвижения }
  ActionDuration = 0.25;

type
  TViewPlay = class(TCastleView)
  published
    { Components designed using CGE editor.
      These fields will be automatically initialized at Start. }
    MainViewport: TCastleViewport;

    PipeSound: TCastleSound;
    PistolSound: TCastleSound;
    ShotgunSound: TCastleSound;
    ARSound: TCastleSound;
    MainTheme: TCastleSound;

    Health: TCastleLabel;
    AmmoPistolLabel: TCastleLabel;
    AmmoShotgunLabel: TCastleLabel;
    AmmoARLabel: TCastleLabel;
    ClockCap: TCastleLabel;

    MapCamera: TCastleCamera;

    EffectTextureField: TSFNode;
    TestTexture1: TImageTextureNode;
    TestTexture2: TImageTextureNode;

    Viewport1: TCastleViewport;

    Pat: TCastleScene;

    Pistol: TCastleScene;
    AR: TCastleScene;
    Pipe: TCastleScene;
    Shotgun: TCastleScene;

    PortalDetect: TCastleTransform;
    PortalDetect1: TCastleTransform;
    PortalDetect2: TCastleTransform;
    PortalDetect3: TCastleTransform;
    PortalDetect4: TCastleTransform;
    FinishBox: TCastleTransform;

    ARDetect: TCastleTransform;
    ShotgunDetect: TCastleTransform;

    AR_to_pick: TCastleScene;
    Shotgun_to_pick: TCastleScene;

    Notifications1: TCastleNotifications;

  private

    { Синхронизировано с MainViewport.Camera.Direction. }
    Direction: TDirection;

    { Высчитывает "Значение + Увеличение",
      выполняет приведение типа между перечислениями и целыми числами,
      и проверяет, что результат находится в диапазоне TDir. }
    function IncreaseDirection(const Value: TDirection;
      const Increase: integer): TDirection;

    procedure Move(const MoveDirection: TDirection);
    procedure Rotate(const RotationChange: integer);
    procedure SelectWeapon(WeaponNumber: integer);
    procedure ShootWeapon(WeaponNumber: integer);
  public

    Enemies: TEnemyList;
    constructor Create(AOwner: TComponent); override;
    procedure Start; override;
    procedure Stop; override;
    procedure Update(const SecondsPassed: single; var HandleInput: boolean); override;
    function Press(const Event: TInputPressRelease): boolean; override;
  end;

var
  ViewPlay: TViewPlay;
  Health_P: integer;
  Ammo_P: integer;
  Ammo_S: integer;
  Ammo_AR: integer;
  Pistol_picked: boolean;
  AR_picked: boolean;
  Shotgun_picked: boolean;
  ClockCapacity: integer;

implementation

uses SysUtils, Math,
  CastleLog, CastleStringUtils, CastleFilesUtils, CastleUtils,
  GameViewMenu;

{ TViewPlay ----------------------------------------------------------------- }

constructor TViewPlay.Create(AOwner: TComponent);
begin
  inherited;
  DesignUrl := 'castle-data:/gameviewplay.castle-user-interface';
end;

procedure TViewPlay.Start;

  procedure CreateTextureEffect(const Scene: TCastleScene);
  var
    Effect: TEffectNode;
    EffectPartFragment, EffectPartVertex: TEffectPartNode;
  begin
    Effect := TEffectNode.Create;
    Effect.Language := slGLSL;

    TestTexture1 := TImageTextureNode.Create;
    TestTexture1.SetUrl(['castle-data:/test_textures/1.png']);
    TestTexture1.KeepExistingBegin;

    TestTexture2 := TImageTextureNode.Create;
    TestTexture2.SetUrl(['castle-data:/test_textures/2.jpg']);
    TestTexture2.KeepExistingBegin;

    EffectTextureField := TSFNode.Create(Effect, True, 'testTexture',
      [TImageTextureNode], TestTexture1);
    Effect.AddCustomField(EffectTextureField);

    EffectPartFragment := TEffectPartNode.Create;
    EffectPartFragment.ShaderType := stFragment;
    EffectPartFragment.SetUrl(['castle-data:/shaders/texture_effect.fs']);

    EffectPartVertex := TEffectPartNode.Create;
    EffectPartVertex.ShaderType := stVertex;
    EffectPartVertex.SetUrl(['castle-data:/shaders/texture_effect.vs']);

    Effect.SetParts([EffectPartFragment, EffectPartVertex]);
    Scene.RootNode.AddChildren([Effect]);
  end;

var
  SoldierScene: TCastleScene;
  Enemy: TEnemy;
  I: integer;
begin
  inherited;

  SoundEngine.Play(MainTheme);

  Notifications1 := DesignedComponent('Notifications1') as TCastleNotifications;
  Pistol := DesignedComponent('Pistol') as TCastleScene;
  AR := DesignedComponent('AR') as TCastleScene;
  Shotgun := DesignedComponent('Shotgun') as TCastleScene;
  Pipe := DesignedComponent('Pipe') as TCastleScene;


  AR_to_pick := DesignedComponent('AR_to_pick') as TCastleScene;
  Shotgun_to_pick := DesignedComponent('Shotgun_to_pick') as TCastleScene;

  AR_picked := False;
  Shotgun_picked := False;

  Health_P := 100;
  Ammo_P := 50;
  ClockCapacity := 100;

  Enemies := TEnemyList.Create(True);
  for I := 1 to 9 do
  begin
    SoldierScene := DesignedComponent('Enemy' + IntToStr(I)) as TCastleScene;
     { Below using nil as Owner of TEnemy, as the Enemies list already "owns"
       instances of this class, i.e. it will free them. }
    Enemy := TEnemy.Create(nil);
    SoldierScene.AddBehavior(Enemy);
    Enemies.Add(Enemy);
  end;


  Pat := DesignedComponent('Pat') as TCastleScene;

  CreateTextureEffect(Pat);

  Viewport1 := DesignedComponent('Viewport1') as TCastleViewport;

  Direction := dirWest;
  MainViewport.Camera.Direction := DirectionVector[Direction];

  Viewport1.Items := MainViewport.Items;
  Viewport1.Camera := MapCamera;

end;

procedure TViewPlay.Stop;
begin
  FreeAndNil(Enemies);
  TestTexture1.KeepExistingEnd;
  TestTexture2.KeepExistingEnd;
  FreeIfUnusedAndNil(TestTexture1);
  FreeIfUnusedAndNil(TestTexture2);
  inherited;
end;

procedure TViewPlay.Update(const SecondsPassed: single; var HandleInput: boolean);
var
  DirectionHorizontal: TVector3;
  Health_L: TCastleLabel;
begin
  inherited;

  Health_L := DesignedComponent('Health') as TCastleLabel;
  AmmoPistolLabel := DesignedComponent('Ammo_P') as TCastleLabel;
  AmmoShotgunLabel := DesignedComponent('Ammo_S') as TCastleLabel;
  AmmoARLabel := DesignedComponent('Ammo_AR') as TCastleLabel;
  ClockCap := DesignedComponent('ClockCap') as TCastleLabel;

  Health_L.Caption := IntToStr(Health_P);
  AmmoPistolLabel.Caption := IntToStr(Ammo_P);
  AmmoShotgunLabel.Caption := IntToStr(Ammo_S);
  AmmoARLabel.Caption := IntToStr(Ammo_AR);
  ClockCap.Caption := IntToStr(ClockCapacity);

  DirectionHorizontal := MainViewport.Camera.Direction;

  Viewport1.Camera.SetView(
    MainViewport.Camera.WorldTranslation + Vector3(0, 10, 0),
    Vector3(0, -1, 0),
    DirectionHorizontal);

  if PortalDetect.WorldBoundingBox.Contains(MainViewport.Camera.WorldTranslation) then
  begin
    MainViewport.Camera.Translation := Vector3(-3.49, 0.51, 12.51);
    Direction := dirEast;
    MainViewport.Camera.Direction := DirectionVector[Direction];
    Exit;
  end;

  if PortalDetect1.WorldBoundingBox.Contains(MainViewport.Camera.WorldTranslation) then
  begin
    MainViewport.Camera.Translation := Vector3(16.51, 0.51, 13.46);
    Direction := dirEast;
    MainViewport.Camera.Direction := DirectionVector[Direction];
    Exit;
  end;

  if PortalDetect2.WorldBoundingBox.Contains(MainViewport.Camera.WorldTranslation) then
  begin
    MainViewport.Camera.Translation := Vector3(15.56, 0.50, -2.35);
    Direction := dirEast;
    MainViewport.Camera.Direction := DirectionVector[Direction];
    Exit;
  end;

  if PortalDetect3.WorldBoundingBox.Contains(MainViewport.Camera.WorldTranslation) then
  begin
    MainViewport.Camera.Translation := Vector3(-19.17, 0.51, 16.85);
    Direction := dirNorth;
    MainViewport.Camera.Direction := DirectionVector[Direction];
    Exit;
  end;

  if PortalDetect4.WorldBoundingBox.Contains(MainViewport.Camera.WorldTranslation) then
  begin
    MainViewport.Camera.Translation := Vector3(-20.33, 0.58, -4.35);
    Direction := dirEast;
    MainViewport.Camera.Direction := DirectionVector[Direction];
    Notifications1.Show('Продолжение следует...');
    Exit;
  end;

  if FinishBox.WorldBoundingBox.Contains(MainViewport.Camera.WorldTranslation) then
  begin
    Sleep(5000);
    Halt;
    Exit;
  end;

  if ARDetect.WorldBoundingBox.Contains(MainViewport.Camera.WorldTranslation) then
  begin
    AR_picked := True;
    AR_to_pick.Exists := False;
    Notifications1.Show('Автомат подобран!');
    Ammo_AR := 60;
    ARDetect.Exists := False;
    Exit;
  end;

  if ShotgunDetect.WorldBoundingBox.Contains(MainViewport.Camera.WorldTranslation) then
  begin
    Shotgun_picked := True;
    Shotgun_to_pick.Exists := False;
    Notifications1.Show('Дробовик подобран!');
    Ammo_S := 50;
    ShotgunDetect.Exists := False;
    Exit;
  end;


  if Health_P <= 0 then
  begin
    Notifications1.Show('Вы погибли');
    Sleep(2000);
    Halt;
  end;

end;

function TViewPlay.IncreaseDirection(const Value: TDirection;
  const Increase: integer): TDirection;
begin
  Result := TDirection(ChangeIntCycle(Ord(Value), Increase, Ord(High(TDirection))));
end;

procedure TViewPlay.Move(const MoveDirection: TDirection);
const
  GridSize = 1;
var
  NewPos, Pos, Dir, Up: TVector3;
begin
  if MainViewport.Camera.Animation then
    Exit;
  MainViewport.Camera.GetWorldView(Pos, Dir, Up);
  NewPos := Pos + DirectionVector[MoveDirection] * GridSize;
  if not MainViewport.Items.WorldSegmentCollision(Pos, NewPos) then
    MainViewport.Camera.AnimateTo(NewPos, Dir, Up, ActionDuration);
end;

procedure TViewPlay.Rotate(const RotationChange: integer);
var
  Pos, Dir, Up: TVector3;
begin
  if MainViewport.Camera.Animation then
    Exit;
  MainViewport.Camera.GetWorldView(Pos, Dir, Up);
  Direction := IncreaseDirection(Direction, RotationChange);
  Dir := DirectionVector[Direction];
  MainViewport.Camera.AnimateTo(Pos, Dir, Up, ActionDuration);
end;

function TViewPlay.Press(const Event: TInputPressRelease): boolean;
var
  HitEnemy: TEnemy;
  Damage_LP: integer;
  Damage_P: integer;
  Damage_S: integer;
  Damage_AR: integer;
  Health_Damage: integer;
begin
  Result := inherited;
  if Result then Exit; // позволяет родительскому классу обрабатывать клавиши

  if Event.IsMouseButton(buttonLeft) then
  begin

    HitEnemy := MainViewport.TransformUnderMouse.FindBehavior(TEnemy) as TEnemy;
    if Pipe.Exists = True then
    begin
      ShootWeapon(1);
      Damage_LP := Random(8);
      if Damage_LP <> 0 then
      begin
        if (MainViewport.TransformUnderMouse <> nil) and
          (MainViewport.TransformUnderMouse.FindBehavior(TEnemy) <> nil) then
        begin
          if HitEnemy.EnemyHealth > 0 then
          begin
            Notifications1.Show('Удар по врагу');
            Notifications1.Show('Нанесено ' + Damage_LP.ToString +
              ' урона');
            HitEnemy.EnemyHealth := HitEnemy.EnemyHealth - Damage_LP;
            if HitEnemy.EnemyHealth <= 0 then
            begin
              HitEnemy.Death;
              Notifications1.Show('Враг убит');
            end;
          end;
        end
        else
          Notifications1.Show('Промах!');
      end;
    end;

    if Pistol.Exists = True then
    begin
      if Ammo_P > 0 then
      begin
        ShootWeapon(2);
        Dec(Ammo_P);
        Damage_P := Random(15 - 5 + 1) + 5;
        if Damage_P <> 0 then
        begin
          if (MainViewport.TransformUnderMouse <> nil) and
            (MainViewport.TransformUnderMouse.FindBehavior(TEnemy) <> nil) then
          begin
            if HitEnemy.EnemyHealth > 0 then
            begin
              Notifications1.Show('Выстрел по врагу');
              Notifications1.Show('Нанесено ' + Damage_P.ToString +
                ' урона');
              HitEnemy.EnemyHealth := HitEnemy.EnemyHealth - Damage_P;
              if HitEnemy.EnemyHealth <= 0 then
              begin
                HitEnemy.Death;
                Notifications1.Show('Враг убит');
              end;
            end;
          end
          else
            Notifications1.Show('Промах!');
        end;
      end;
    end;

    if Shotgun.Exists = True then
    begin
      if Ammo_S > 0 then
      begin
        ShootWeapon(3);
        Dec(Ammo_S);
        Damage_S := Random(30 - 15 + 1) + 15;
        if Damage_S <> 0 then
        begin
          if (MainViewport.TransformUnderMouse <> nil) and
            (MainViewport.TransformUnderMouse.FindBehavior(TEnemy) <> nil) then
          begin
            if HitEnemy.EnemyHealth > 0 then
            begin
              Notifications1.Show('Выстрел по врагу');
              Notifications1.Show('Нанесено ' + Damage_S.ToString +
                ' урона');
              HitEnemy.EnemyHealth := HitEnemy.EnemyHealth - Damage_S;
              if HitEnemy.EnemyHealth <= 0 then
              begin
                HitEnemy.Death;
                Notifications1.Show('Враг убит');
              end;
            end;
          end
          else
            Notifications1.Show('Промах!');
        end;
      end;
    end;

    if AR.Exists = True then
    begin
      if Ammo_P > 0 then
      begin
        ShootWeapon(4);
        Ammo_AR := Ammo_AR - 3;
        Damage_AR := Random(60 - 30 + 1) + 30;
        if Damage_AR <> 0 then
        begin
          if (MainViewport.TransformUnderMouse <> nil) and
            (MainViewport.TransformUnderMouse.FindBehavior(TEnemy) <> nil) then
          begin
            if HitEnemy.EnemyHealth > 0 then
            begin
              Notifications1.Show('Выстрел по врагу');
              Notifications1.Show('Нанесено ' + Damage_AR.ToString +
                ' урона');
              HitEnemy.EnemyHealth := HitEnemy.EnemyHealth - Damage_AR;
              if HitEnemy.EnemyHealth <= 0 then
              begin
                HitEnemy.Death;
                Notifications1.Show('Враг убит');
              end;
            end;
          end
          else
            Notifications1.Show('Промах!');
        end;
      end;
    end;

    if (MainViewport.TransformUnderMouse <> nil) and
      (MainViewport.TransformUnderMouse.FindBehavior(TEnemy) <> nil) then
      if HitEnemy.Dead = False then
      begin
        Health_Damage := Random(20 - 5 + 1) + 5;
        Notifications1.Show('Вы получили урон!');
        Notifications1.Show('Нанесено ' + Health_Damage.ToString + ' урона');
        HitEnemy.Attack;
        Health_P := Health_P - Health_Damage;
      end;

    Exit(True);
  end;

  if not MainViewport.Camera.Animation then
  begin
    if Event.IsKey(keyW) then
    begin
      Move(IncreaseDirection(Direction, 0));
      Exit(True);
    end;
    if Event.IsKey(keyS) then
    begin
      Move(IncreaseDirection(Direction, 2));
      Exit(True);
    end;
    if Event.IsKey(keyD) then
    begin
      Move(IncreaseDirection(Direction, 1));
      Exit(True);
    end;
    if Event.IsKey(keyA) then
    begin
      Move(IncreaseDirection(Direction, -1));
      Exit(True);
    end;

    if Event.IsKey(keyQ) then
    begin
      Rotate(-1);
      Exit(True);
    end;
    if Event.IsKey(keyE) then
    begin
      Rotate(1);
      Exit(True);
    end;
  end;

  if Event.IsKey(keyV) then
  begin
    if Health_P < 100 then
    begin
      ClockCapacity := ClockCapacity - 25;
      Health_P := 100;
    end;
    Exit(True);
  end;

  if Event.IsKey(keyY) then
  begin
    MainViewport.Camera.Translation := Vector3(-3.49, 0.51, 12.51);
    Direction := dirEast;
    MainViewport.Camera.Direction := DirectionVector[Direction];
    Exit(True);
  end;

  if Event.IsKey(keyU) then
  begin
    MainViewport.Camera.Translation := Vector3(16.51, 0.51, 13.46);
    Direction := dirEast;
    MainViewport.Camera.Direction := DirectionVector[Direction];
    Exit(True);
  end;

  if Event.IsKey(keyI) then
  begin
    MainViewport.Camera.Translation := Vector3(15.56, 0.50, -2.35);
    Direction := dirEast;
    MainViewport.Camera.Direction := DirectionVector[Direction];
    Exit(True);
  end;

  if Event.IsKey(keyO) then
  begin
    MainViewport.Camera.Translation := Vector3(-19.17, 0.51, 16.85);
    Direction := dirNorth;
    MainViewport.Camera.Direction := DirectionVector[Direction];
    Exit(True);
  end;

  if Event.IsKey(keyP) then
  begin
    MainViewport.Camera.Translation := Vector3(-20.33, 0.58, -4.35);
    Direction := dirEast;
    MainViewport.Camera.Direction := DirectionVector[Direction];
    Notifications1.Show('Продолжение следует...');
    Exit(True);
  end;

  if Event.IsKey(keyF5) then
  begin
    Container.SaveScreenToDefaultFile;
    Exit(True);
  end;

  if Event.IsKey(keyEscape) then
  begin
    Container.View := ViewMenu;
    Exit(True);
  end;

  if Event.IsKey(key1) then
  begin
    SelectWeapon(1);
    Exit(True);
  end;

  if Event.IsKey(key2) then
  begin
    SelectWeapon(2);
    Exit(True);
  end;

  if Event.IsKey(key3) then
  begin
    SelectWeapon(3);
    Exit(True);
  end;

  if Event.IsKey(key4) then
  begin
    SelectWeapon(4);
    Exit(True);
  end;

  if Event.IsKey(keyT) then
  begin
    if EffectTextureField.Value = TestTexture1 then
      EffectTextureField.Send(TestTexture2)
    else
      EffectTextureField.Send(TestTexture1);

    Pat.GLContextClose;
  end;
end;


procedure TViewPlay.SelectWeapon(WeaponNumber: integer);
begin
  if WeaponNumber = 1 then
  begin
    Pipe.Exists := True;
    Pistol.Exists := False;
    AR.Exists := False;
    Shotgun.Exists := False;
  end;

  if WeaponNumber = 2 then
  begin
    Pipe.Exists := False;
    Pistol.Exists := True;
    AR.Exists := False;
    Shotgun.Exists := False;
  end;

  if WeaponNumber = 3 then
  begin
    if Shotgun_picked = True then
    begin
      Pipe.Exists := False;
      Pistol.Exists := False;
      AR.Exists := False;
      Shotgun.Exists := True;
    end;
  end;

  if WeaponNumber = 4 then
  begin
    if AR_picked = True then
    begin
      Pipe.Exists := False;
      Pistol.Exists := False;
      AR.Exists := True;
      Shotgun.Exists := False;
    end;
  end;
end;

procedure TViewPlay.ShootWeapon(WeaponNumber: integer);
begin
  if WeaponNumber = 1 then
  begin
    Pipe.PlayAnimation('attack', False);
    SoundEngine.Play(PipeSound);
  end;

  if WeaponNumber = 2 then
  begin
    Pistol.PlayAnimation('shoot', False);
    SoundEngine.Play(PistolSound);
  end;

  if WeaponNumber = 3 then
  begin
    if Shotgun_picked = True then
    begin
      Shotgun.PlayAnimation('shoot', False);
      SoundEngine.Play(ShotgunSound);
    end;
  end;

  if WeaponNumber = 4 then
  begin
    if AR_picked = True then
    begin
      AR.PlayAnimation('shoot', False);
      SoundEngine.Play(ARSound);
    end;
  end;
end;

end.
