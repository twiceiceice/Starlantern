# C 스타일 아트 연결

참고 그림은 art/references/character-directions.png의 오른쪽 C입니다.
3~4등신, 둥근 얼굴·손·신발, 따뜻한 천과 가죽, 큰 색 덩어리로 직업이 읽히는 방향입니다.
그림은 AI로 만든 디자인 참고 이미지이며 실제 3D 모델이 아닙니다.

현재 CharacterView는 구·캡슐로 몸, 머리, 옷, 배낭과 도구를 표현합니다.
플레이어·목수·운반원이 같은 비율을 쓰지만 스켈레톤, 손가락, 정교한 도구 접촉은 아직 없습니다.

## 자산 위치

- art/source/characters/: Blender 원본과 리깅 작업
- assets/models/characters/: 게임용 GLB
- assets/models/props/: 텐트·수레·도구·건물
- assets/textures/: 텍스처
- assets/audio/: 음악·효과음

Godot는 assets의 GLB를 가져와 장면으로 사용할 수 있습니다.
가져온 장면을 직접 고치기보다는 시각 표현용 상속 장면/래퍼 장면에 AnimationTree와 도구 부착점을 둡니다.
scripts/visuals/character_view.gd의 외부 동작 규약을 유지하면서 내부 구현을 교체합니다.
원본의 방향이 다르면 이 시각 표현 루트 안에서만 회전시켜 보정합니다.

## 공통 규격

- 키 약 1.9m, 발바닥 중앙 원점, +Y 위, 캐릭터 정면 +Z.
- Camera3D의 정면은 -Z이므로 캐릭터와 카메라 축을 혼동하지 않습니다.
- 게임 규칙은 이동과 회전을 결정하고 첫 모델은 제자리 애니메이션을 사용합니다.
- 플레이어와 주민의 공통 스켈레톤을 먼저 정합니다.
- 오른손/왼손 부착점 이름: grip_r, grip_l. 도구별 손잡이 원점을 함께 기록합니다.
- 첫 클립: Idle, Walk, Run, Jump, Slash, Slam, Dodge, WorkHammer, Carry.
- 현재 API: animate(delta, speed, grounded, action, progress, carrying).

첫 완성 목표는 주인공과 목수 두 명이 같은 세계의 사람처럼 보이며 발, 손, 도구가 자연스럽게 닿는 것입니다.
현재 임시 모델에 세부 장식을 계속 붙이기보다는 완성 모델과 애니메이션 전환을 검증합니다.
