unit GameEnemy;

interface

uses Classes, Generics.Collections,
  CastleVectors, CastleScene, CastleTransform;

type
  { Simple enemy intelligence.
    It controls the parent Scene (TCastleScene): moves it, runs animations of it etc.

    This is a TCastleBehavior descendant,
    and is inserted to parent like EnemyScene.AddBehavior(...).
    You can get the TEnemy instance of a TCastleScene,
    by taking "Scene.FindBehavior(TEnemy)".

    Other ways of making an association TCastleScene <-> TEnemy logic are possible:

    - TEnemy could be an independent class (not connected to any CGE class),
      and simply have a reference to CGE TCastleScene instance.

      This makes it easy to map TEnemy->TCastleScene.
      To map TCastleScene->TEnemy you could e.g. use TCastleScene.Tag,
      or a dedicated map structure like TDictionary from Generics.Collections.

    - You could also make TEnemy a descendant of TCastleScene.

    Note that TCastleBehavior or TCastleTransform descendants could be
    registered in the CGE editor to visually add and edit them from editor.
    See https://castle-engine.io/manual_editor.php#section_custom_components .
    In this unit we call RegisterSerializableComponent,
    so you only need to add editor_units="GameEnemy" to CastleEngineManifest.xml to see it in action.
  }
  TEnemy = class(TCastleBehavior)
  strict private
    Scene: TCastleScene;
    //MoveDirection: Integer; //< Always 1 or -1
    Dead: Boolean;
  public
    EnemyHealth: Integer;
    constructor Create(AOwner: TComponent); override;
    procedure ParentChanged; override;
    procedure Update(const SecondsPassed: Single; var RemoveMe: TRemoveType); override;
    procedure Hurt;
    procedure Death;
  end;

  TEnemyList = {$ifdef FPC}specialize{$endif} TObjectList<TEnemy>;


implementation

uses CastleComponentSerialize;

constructor TEnemy.Create(AOwner: TComponent);
begin
  inherited;
  EnemyHealth := 30;
end;

procedure TEnemy.ParentChanged;
begin
  inherited;
  Scene := Parent as TCastleScene; // TEnemy can only be added as behavior to TCastleScene
  Scene.PlayAnimation('idle', true);
end;

procedure TEnemy.Update(const SecondsPassed: Single; var RemoveMe: TRemoveType);
//const
  //MovingSpeed = 2;
begin
  inherited;

  if Dead then Exit;
end;

procedure TEnemy.Hurt;
begin

end;

procedure TEnemy.Death;
begin
  Scene.PlayAnimation('death', false);
  Scene.Pickable := false;
  Scene.Collides := false;
  Dead := true;
end;

initialization
  RegisterSerializableComponent(TEnemy, 'Enemy');
end.
