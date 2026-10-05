# Godot 기반 구조

## 2026-10-05 결정

PC 싱글 플레이 본편을 목표로 Godot 4.7.2와 GDScript를 사용합니다.
처음에는 OpenGL Compatibility 렌더러로 입력·게임 규칙·배포를 안정화합니다.
더 고급 조명이 필요해지면 목표 PC에서 측정하고 Forward+ 도입 여부를 결정합니다.
렌더러 변경 자체가 아트 품질을 완성해 주지는 않습니다.

## 실행 관계

```text
main.tscn → app/game.gd
             ├─ Expedition (진행·보상, RefCounted)
             ├─ LanternNetwork (등불 빛·기름, RefCounted)
             ├─ GameWorld (일시 정지되는 게임 장면)
             │    ├─ expedition_valley.tscn (물리 지형·길찾기)
             │    ├─ ExpeditionPlayer
             │    ├─ FollowCamera → SpringArm3D → Camera3D
             │    ├─ RuinGuardian × 3
             │    ├─ ExpeditionWorker × 2
             │    ├─ LanternGlow (LanternNetwork의 빛 반경 표시)
             │    ├─ MarchDirector (app: 게시판·등불 자리·행렬·기지 건설 연결)
             │    │    ├─ Caravan / QuestBoard (game: 숫자 규칙, RefCounted)
             │    │    ├─ CaravanView (MultiMesh 대열: 사람·짐노새·짐소·마차), SettlementView (기지 건물)
             │    │    └─ 길목 파수꾼·우두머리·습격자 (RuinGuardian)
             │    └─ CombatEffects
             └─ ExpeditionHud (일시 정지 중에도 작동)
```

전투 판정은 위치·방향·거리·높이를 보고 계산하고 World 레이어의 광선 검사로 벽을 통과한 공격을 막습니다.
장비 메시의 생김새가 피해 판정을 결정하지 않습니다. 준비 시간 → 적중 → 마무리 동작을 분리했습니다.
이후 실제 애니메이션의 적중 프레임에 맞춰 데이터를 조정할 수 있습니다.

캐릭터는 CharacterBody3D로 움직이고, 충돌 캡슐과 시각 표현을 분리합니다.
CharacterView는 현재 임시 메시를 만들고 걷기·공격·운반 포즈를 표현합니다.
이 경계를 유지하면서 GLB, Skeleton3D, AnimationPlayer / AnimationTree로 교체합니다.

## 원정과 NPC

진행: CAMP → MARCH → BASE → CLEARING → RECOVERING → REPORT → COMPLETE.

### 행군과 기지 (app/march_director.gd)

- 지도는 남쪽 출발 야영지(z 150) → 이끼 숲길(구간 1) → 바람 고갯길(구간 2) → 전진 기지 터(z 16) → 유적 순서입니다.
- 단계마다 QuestBoard가 두 퀘스트를 제시하고 플레이어는 하나만 맡습니다. 퀘스트의 역할(토벌·등불지기·운반·방어)이
  그 단계에서 플레이어가 할 일입니다.
- 행군 콘텐츠는 game/march_plan.gd의 데이터입니다. 구간 → 지점(stretch, 경로 거리 end) → 역할별 연퀘 단계.
  단계 종류는 kill(파수꾼), light(등불 자리), visit(표시 지점 방문)입니다. 두 역할의 단계가 모두 끝나야
  행렬이 지점까지 전진하고, 도착한 뒤에야 다음 지점의 단계가 열립니다. 분량은 이 표에 지점과 단계를 더해 늘립니다.
  light 단계의 등불 자리는 각 지점까지 길이 끊김 없이 밝도록 배치해야 합니다(반경 10m).
- 맡지 않은 역할의 단계는 NPC 조가 처리합니다. 등불꾼은 6초 뒤 등불을 세우고, 정찰대는 7초 뒤 조사를 마치며,
  경비대는 8초마다 파수꾼 하나를 제거하고 3명을 잃습니다. 기지 습격도 경비대가 같은 방식으로 막습니다.
- 연속 퀘스트: 퀘스트의 next가 다음 단계에서 같은 역할의 퀘스트를 대체합니다(구간 1 토벌 → 우두머리 추적).
  chief 퀘스트는 해당 구간 마지막 지점에 추적·우두머리 단계를 덧붙입니다.
- Caravan은 사람·노새·짐마차·식량·경로상의 진행 거리만 가집니다. 앞머리는 빛이 있는 땅으로만 한 걸음씩 나아가고,
  14m 안에 살아 있는 적이 있으면 멈춥니다(8초 뒤 경비대가 제거). 짐소는 마차마다 하나이고 식량을 사람의 3배 먹습니다.
- CaravanView는 6개 블록(4열 사람 + 양옆 짐노새, 뒤에 짐소·마차 두 줄)을 경로를 따라 배치합니다. 대열이 경로보다 길어서
  차례가 오지 않은 구성원은 야영지 자리에서 기다리다 마지막 10m 동안 길로 걸어 나옵니다. 행렬이 멈춰 있으면 변환을 다시 쓰지 않습니다. 식량은 (사람 + 노새×2)/600 per second로 줄고, 바닥나면 3초마다 1명이 이탈합니다.
- 기지 건설은 초당 1.25%, 운반한 상자 하나당 +10%이며 습격자가 남아 있으면 멈춥니다. 완성 시 캠프·리스폰·인부의 집이 기지로 옮겨집니다.
- 기지 건물의 자리는 world_factory가 미리 길찾기 장애물로 비워 둡니다. 저장된 NavMesh는 런타임 건물을 따라가지 않습니다.

### 유적

- 모집 전에 적을 모두 쓰러뜨려도, 기지가 완성되면 회수 단계로 연결됩니다.
- 안전 구역은 game/lantern_network.gd의 등불 빛입니다. 캠프와 길가 등불은 고정 빛이고,
  유적 안은 플레이어가 E로 세우는 전진 등불 하나로만 밝힙니다. 다시 E를 누르면 옮겨집니다.
- 인부는 옆자리가 빛 안일 때만 따라가고, 아니면 빛의 경계에서 기다립니다.
- 전진 등불은 세운 뒤 기름을 태우며(90초), 기름이 줄면 반경이 8m에서 3m까지 줄어듭니다.
  캠프에서 E로 기름을 채울 수 있어 막힘이 없습니다. 고정 등불은 기름과 무관합니다.
- 파수꾼 전멸과 작업장의 빛이 모두 갖춰지면 작업장으로 이동 → 작업 → 상자를 들고 캠프로 복귀합니다.
  작업 중 빛이 물러나면 진행도를 유지한 채 멈추고, 빛이 돌아오면 이어서 합니다.
- 서로 다른 인부 둘의 도착을 기록하며 중복 도착으로 보상을 늘릴 수 없습니다.
- 플레이어가 캠프에 도착해 정산해야 보상을 받습니다. 장부는 정산을 한 번만 허용합니다.
- NPC는 무적 비전투 인력입니다. 부상·구조·호위 실패 조건은 후속 설계 대상입니다.

길찾기는 NavigationRegion3D와 NavigationAgent3D를 사용합니다.
현재 저장된 NavigationMesh는 평지에 장애물 주변을 제외한 셀들을 연결한 형태입니다.
오브젝트 회피 및 다층 경사로가 필요한 실제 던전에서는 Godot의 메시 베이크로 바꿉니다.
NavMesh는 에디터에서 볼 수 있으며 동적인 건축 변경을 자동으로 따라가지 않습니다.

## 입력과 정지

입력 이름과 기본 키는 core/input_setup.gd에서 초기화합니다.
일시 정지는 GameWorld 전체에 적용하므로 이동·공격 타이머·NPC 작업이 함께 멈춥니다.
Esc와 창 포커스 이탈은 커서를 해제합니다. 계속하기를 누르면 마우스를 다시 잡습니다.
카메라는 SpringArm3D로 지형을 검사하여 벽 앞에서 거리를 줄입니다.

## 검증

tools/check.ps1은 공식 실행 파일의 임포트와 테스트 출력에서 종료 코드뿐 아니라 SCRIPT ERROR / ERROR도 확인합니다.
tests/run_tests.gd는 입력 방향·공격 범위·진행 장부에 이어 실제 장면을 열고 물리 이동, 점프, 충돌,
회피 충전·무적·공격 취소, 실제 적에게 적중, 경고 바닥 이탈, NPC 길찾기·작업·복귀, 정산과 정지를 검사합니다.
키 입력은 엔진의 Input action API로 주입합니다. 실제 사람이 키보드·마우스로 플레이한 검사와 구분합니다.

렌더 검사는 tools/capture_scene.gd를 사용합니다. 게임에서 사용되는 실제 장면·HUD를 GPU로 렌더합니다.
내보낸 Windows 빌드도 시작 및 렌더 검사를 별도로 진행합니다.

참고: [Godot 명령행](https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html),
[3D 길찾기](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_introduction_3d.html),
[애니메이션](https://docs.godotengine.org/en/stable/tutorials/animation/animation_tree.html).
