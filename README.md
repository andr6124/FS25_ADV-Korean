# FS25_한글패치 (FS25_ADV-Korean)

**Farming Simulator 25**의 기본 게임 한국어 번역을 다듬는 PC용 모드입니다.

기본 게임 문자열 5,763개를 모두 검토해서 **1,785개를 고쳤습니다.**
- 어색한 기계번역투 문장을 자연스러운 한국어로 바꿨습니다.
- 용어를 통일하고 오역을 바로잡았습니다.

## 무엇이 바뀌나요

- **오역 수정**
  - 이앙기 → 점파기(planter)
  - 제초기 → 파쇄기(mulcher)
  - 왕겨 → 여물(chaff)
  - 재 → 물푸레나무
  - 메뚜기 → 아까시나무
  - 구리 → 배럴 공방 등
  - 빠진 문장도 채웠습니다.
- **용어 통일**
  - 짚더미·베일 → **베일**
  - 사일지·사일리지 → **사일리지**
  - 임무·미션·계약 → **계약**
  - 임대 → **임차**
  - 롱그레인 벼 → **장립종 벼**
  - 그린빈 → **강낭콩** 등
- **익숙한 말은 그대로**: 베일러, 헤더, 팔레트, 텔레핸들러, 포워더처럼 플레이어가 익숙하게 쓰는 외래어는 유지했습니다.
- **문체**: 도움말·안내·경고는 합쇼체, 버튼·메뉴는 명사형으로 맞췄습니다. 업적 설명은 원문의 재치를 살려 구어체로 썼습니다.
- **레시피 이름**: "귀리 밀가루"처럼 영어 어순을 그대로 옮긴 이름을 고쳤습니다.
  - 귀리가루, 밀가루, 보리가루, 수숫가루
  - 설탕 (사탕무), 직물 (양모)
- **지도 범례**: 수확 후 갈이, 파종 준비됨, 다지기 필요

## 설치

1. [Releases](../../releases)에서 **`FS25_ADV_Korean.zip`**을 받습니다.
2. **게임을 완전히 종료한 상태에서** zip을 **압축을 풀지 말고 그대로** 모드 폴더에 넣습니다.
   - 모드 폴더: `문서\My Games\FarmingSimulator2025\mods`
   - zip 파일 이름을 바꾸지 마십시오. FS25는 한글 등이 들어간 모드 파일 이름을 읽지 못합니다.
3. 게임을 켜고, 세이브를 불러올 때 모드 선택 화면에서 **FS25_한글패치**를 체크합니다.

게임이 켜져 있는 동안 zip을 교체하면 다음에 세이브를 불러올 때 모드를 읽지 못합니다. 업데이트할 때도 게임을 먼저 종료하십시오.

## 동작 조건과 한계

- **게임 언어가 한국어일 때만** 동작합니다. 다른 언어에서는 아무것도 바꾸지 않습니다.
- **PC 전용**입니다. 콘솔은 Lua 스크립트 모드를 쓸 수 없습니다.
- 모드는 세이브를 불러올 때 적용됩니다. 그래서 **메인 메뉴**와 세이브를 불러오기 전 화면은 기존 번역 그대로입니다.
- 기존 번역문 하나를 여러 곳에서 함께 쓰는 일부 문구(약 49개)는 게임 시작 때 만들어진 화면에서 기존 번역으로 보일 수 있습니다.
- 세이브 데이터는 건드리지 않습니다. 언제든 켜고 끌 수 있습니다.
- 멀티플레이에서는 각자 자기 화면의 글자만 바뀝니다.

## 호환 버전

- 게임 버전 **1.23.1.0** 기준으로 만들었습니다.
- 게임 업데이트로 영어 원문이 바뀐 문장은 모드가 자동으로 건너뜁니다. 그래서 업데이트 뒤에도 엉뚱한 번역이 표시되지 않습니다.

## 문제 신고

잘못된 번역이나 어색한 표현은 [Issues](../../issues)에 남겨 주십시오. 게임 화면 스크린샷과 문구가 함께 있으면 빨리 고칠 수 있습니다.

## 참고

- 이 모드는 무료이며 GIANTS Software와 관계없는 비공식 모드입니다.
- Farming Simulator 및 게임 텍스트의 권리는 GIANTS Software에 있습니다.
- 공식 번역 개선을 위해 GIANTS 피드백 포털(https://feedback.giants-software.com)에도 개선 내용을 전달할 수 있습니다.

---

**English**: A PC mod for Farming Simulator 25 that improves the base game's Korean translation. 1,785 of 5,763 strings were revised to fix mistranslations, unify terminology and remove machine-translation style. It only takes effect when the game language is Korean. Download `FS25_ADV_Korean.zip` from Releases and put it into `Documents\My Games\FarmingSimulator2025\mods` without unpacking or renaming it. Quit the game completely before installing or updating. Unofficial, free, not affiliated with GIANTS Software.
