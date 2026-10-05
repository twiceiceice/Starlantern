class_name CareerContracts
extends RefCounted
## Authored tasks use existing navigable ground. Markers add no solid obstacles.
const QUESTS := {
	"hero": [
		{"title": "먼저 돌아온 적들", "story": "길드 토벌관: 철수한 줄 알았던 파수꾼이 다시 모이고 있습니다. 뒤따를 조사대의 길을 확보해 주세요.", "steps": [
			{"kind": "kill", "text": "재집결한 파수꾼 둘 토벌", "points": [Vector3(-3,0,-17), Vector3(3,0,-22)], "health": 132.0}]},
		{"title": "깨어난 추격자", "story": "별문의 잔향이 정예 파수꾼을 깨웠습니다. 발자국을 조사해 추격자를 찾아내세요.", "steps": [
			{"kind": "survey", "text": "추격자의 흔적 조사", "points": [Vector3(-5,0,-16)]},
			{"kind": "kill", "text": "별문 추격자 처치", "points": [Vector3(0,0,-24)], "health": 230.0}]},
		{"title": "별문의 마지막 수문장", "story": "토벌관: 수문장의 넓은 충격파와 빠른 추격타를 읽으세요. 약점 낙인은 어떤 전투 방식과도 이어집니다.", "steps": [
			{"kind": "kill", "text": "수문장의 두 예고 패턴을 피하며 토벌", "points": [Vector3(0,0,-23)], "health": 420.0, "boss": true}]},
	],
	"warden": [
		{"title": "학자를 집으로", "story": "학자 세온이 입구 안에 고립됐습니다. 곁을 지키며 기지 앞 안전선까지 데려오세요. 적을 공격하면 학자에게 향하던 시선을 돌릴 수 있습니다.", "steps": [
			{"kind": "escort", "text": "학자 세온을 안전선까지 호위", "points": [Vector3(0,0,-24), Vector3(0,0,7)], "waves": 1}]},
		{"title": "꺼지지 않는 불씨", "story": "의무대의 보급품을 회수할 시간이 필요합니다. 두 차례 공격을 막으며 보급품 곁을 지켜 주세요.", "steps": [
			{"kind": "defend", "text": "보급품 24초 방어 · 곁에 있어야 진행", "points": [Vector3(0,0,-13)], "seconds": 24.0}]},
		{"title": "마지막 호송", "story": "부상자를 태운 수레가 마지막으로 떠납니다. 세 번의 매복에서 결계와 공격을 조합해 수레를 귀환시키세요.", "steps": [
			{"kind": "escort", "text": "부상자 수레를 세 번의 매복에서 보호", "points": [Vector3(0,0,-26), Vector3(0,0,9)], "waves": 3}]},
	],
	"explorer": [
		{"title": "측량대의 흔적", "story": "정찰대: 토벌 뒤에도 남은 흔적이 있습니다. 첫 측량대가 남긴 세 표식을 연결해 보세요.", "steps": [
			{"kind": "survey", "text": "측량 표식 세 곳 조사", "points": [Vector3(-6,0,-16), Vector3(6,0,-20), Vector3(0,0,-27)]}]},
		{"title": "끊긴 표식", "story": "룬의 맥동이 길을 삼키고 있습니다. 붉은 예고를 피하며 표식의 순서대로 귀환로를 기록하세요. 바람길을 켜면 조사도 빨라집니다.", "steps": [
			{"kind": "survey", "text": "맥동을 피하며 귀환로 표식 조사", "points": [Vector3(5,0,-25), Vector3(-5,0,-22), Vector3(0,0,-14)], "hazard": true}]},
		{"title": "돌아오는 길도 지도다", "story": "길잡이: 깊이 들어가는 것만큼 살아 돌아올 길을 남기는 일이 중요합니다. 마지막 표식을 기록하고 추격대를 뚫고 기지로 돌아오세요.", "steps": [
			{"kind": "survey", "text": "상층 정거장의 귀환 좌표 조사", "points": [Vector3(0,0,-27)], "hazard": true},
			{"kind": "kill", "text": "귀환로를 봉쇄한 추격대 돌파", "points": [Vector3(-3,0,-16), Vector3(3,0,-13)], "health": 132.0},
			{"kind": "survey", "text": "안전선에 귀환 표식 남기기", "points": [Vector3(0,0,7)]}]},
	],
	"artisan": [
		{"title": "수리할 수 있는 별빛", "story": "보급관 누리: 평범한 부품은 제가 준비했습니다. 보급 상자에서 받아 현장의 등불 장치 세 곳을 복구해 주세요.", "steps": [
			{"kind": "supply", "text": "기지 보급 상자에서 부품 받기", "points": [Vector3(-3,0,12)]},
			{"kind": "repair", "text": "고장 난 등불 장치 복구", "points": [Vector3(-5,0,-14), Vector3(5,0,-18), Vector3(0,0,-25)]}]},
		{"title": "회수용 골렘", "story": "룬공방: 평범한 외장은 길드가 조달합니다. 파수꾼의 핵 두 개를 회수해 현장 골렘에 연결해 주세요.", "steps": [
			{"kind": "kill", "text": "파수꾼에게서 동력핵 두 개 확보", "points": [Vector3(-3,0,-18), Vector3(3,0,-23)], "health": 150.0},
			{"kind": "repair", "text": "회수 골렘의 동력 장치 조립", "points": [Vector3(0,0,-20)]}]},
		{"title": "별문 안정화", "story": "세 안정기를 연결하면 원정대가 안전하게 연구할 수 있습니다. 경비 파수꾼을 막고 장치를 수리하세요. 룬 골렘이 작업 시간을 벌어 줍니다.", "steps": [
			{"kind": "supply", "text": "길드가 조달한 안정기 부품 받기", "points": [Vector3(-3,0,12)]},
			{"kind": "repair", "text": "경비 파수꾼을 막고 안정기 세 곳 복구", "points": [Vector3(-5,0,-18), Vector3(5,0,-23), Vector3(0,0,-27)], "guarded": true}]},
	],
}
