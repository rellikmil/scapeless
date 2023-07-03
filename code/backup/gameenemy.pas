unit GameEnemy;

interface

uses Classes, Generics.Collections,
  CastleVectors, CastleScene, CastleTransform;

type
  TEnemy = class(TCastleBehavior)
  strict private
    Scene: TCastleScene;
  public
    Dead: Boolean;
    EnemyHealth: Integer;
    Attacking: Boolean;
    constructor Create(AOwner: TComponent); override;
    procedure ParentChanged; override;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    procedure Death;
    procedure Attack;
  end;

  TEnemyList = {$ifdef FPC}specialize{$endif} TObjectList<TEnemy>;


implementation

uses CastleComponentSerialize;

constructor TEnemy.Create(AOwner: TComponent);
begin
  inherited;
  EnemyHealth := 30;
  Attacking := false;
end;

procedure TEnemy.ParentChanged;
begin
  inherited;
  Scene := Parent as TCastleScene; // TEnemy can only be added as behavior to TCastleScene
  Scene.PlayAnimation('idle', true);
end;

procedure TEnemy.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
begin
  inherited;

  if Dead then Exit;
end;

procedure TEnemy.Death;
begin
  Scene.PlayAnimation('death', false);
  Scene.Pickable := false;
  Scene.Collides := false;
  Dead := true;
end;

procedure TEnemy.Attack;
begin
  Scene.PlayAnimation('attack', false);
end;

initialization
  RegisterSerializableComponent(TEnemy, 'Enemy');
end.
