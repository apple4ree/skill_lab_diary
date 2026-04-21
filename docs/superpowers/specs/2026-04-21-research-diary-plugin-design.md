---
title: Research Diary Plugin — Design Spec
date: 2026-04-21
status: approved (brainstorming)
---

# Research Diary Plugin — Design Spec

## 1. Overview

연구실 구성원이 각 프로젝트에서 하루 단위 연구일지를 구조화된 형식으로 작성하고,
로컬 디렉토리와 개인 GitHub 레포에 자동 누적·푸시하도록 돕는 Claude Code 플러그인.

### 사용 흐름

```
[작업 디렉토리] $ claude
> ... 하루 동안 연구 작업 ...
> /research-diary
  → Claude가 현 세션 대화 + 기존 일지(있으면)를 읽고
  → 필드별로 merge하여 작성
  → 로컬 ~/research-diary/<project>/<YYYY-MM-DD>.md 에 저장
  → git commit + push → 사용자 개인 GitHub repo
```

### 주요 설계 결정

- **트리거**: 수동 슬래시 커맨드 `/research-diary` (v1). 자동 훅은 YAGNI.
- **저장 모델**: 로컬 디렉토리 하나가 곧 설정된 GitHub repo의 git clone. 로컬 축적과 원격 push가 같은 디렉토리를 거침.
- **같은 날 재실행**: 기존 내용 보존 + 섹션 말미에 append. 기존 내용 수정이 필요한 경우 사용자 확인.
- **세션 범위**: 현재 세션 + 기존 일지(오전 작성분)를 참조. `~/.claude/projects/<hash>/*.jsonl` 직접 파싱은 하지 않음.
- **배포**: Plugin 형태로 연구실 공통 배포, 개인 설정은 `settings.json` 환경변수.

---

## 2. 아키텍처

플러그인은 4개 유닛으로 분리된다. 각 유닛의 책임을 명확히 해서 독립 이해·교체가 가능하도록 한다.

| 유닛 | 역할 | 호출 주체 |
|---|---|---|
| `SKILL.md` | `/research-diary` 엔트리. Claude에게 실행 절차를 지시 | Claude Code (스킬 활성화 시) |
| `scripts/diary_setup.sh` | 최초 실행 시 로컬 diary 디렉토리 초기화 (clone 또는 init) | Claude가 bash로 호출 |
| `scripts/diary_commit.sh` | 작성된 일지를 git add/commit/push | Claude가 bash로 호출 |
| `references/diary_format.md` | 필드 템플릿·예시·merge 규칙 상세 | Claude가 필요 시 Read |

### 데이터 흐름

```
current session transcript
            +
existing ~/research-diary/<project>/<today>.md  (if any)
            ↓
       [Claude merges per §5 rules]
            ↓
      new/updated <today>.md
            ↓
   git add + commit + push → remote GitHub repo
```

---

## 3. 설정 (Config)

각 구성원은 `~/.claude/settings.json`에 환경변수로 개인 설정을 둔다.

```json
{
  "env": {
    "DIARY_LOCAL_PATH": "/home/dgu/research-diary",
    "DIARY_GIT_REMOTE": "git@github.com:dgu/research-diary.git"
  }
}
```

| 변수 | 기본값 | 동작 |
|---|---|---|
| `DIARY_LOCAL_PATH` | `~/research-diary` | 로컬 일지 저장소 경로 |
| `DIARY_GIT_REMOTE` | (미설정) | 미설정 시 로컬 전용 모드. 경고 표시, push 스킵 |

### 프로젝트 식별

기본: 현재 작업 디렉토리의 basename
- 예: `/home/dgu/skill_lab_diary` → `skill_lab_diary`

Override: 작업 디렉토리에 `.diary-project-name` 파일이 존재하면 그 내용을 프로젝트명으로 사용
(이름 충돌이나 여러 하위 프로젝트를 같은 이름으로 묶고 싶을 때).

---

## 4. 일지 파일 포맷

### 경로

```
${DIARY_LOCAL_PATH}/<project>/<YYYY-MM-DD>.md
```

예: `/home/dgu/research-diary/skill_lab_diary/2026-04-21.md`

### 구조

YAML frontmatter + Markdown 섹션:

```markdown
---
date: 2026-04-21
project: skill_lab_diary
server: dgu-workstation
work_hours:
  - 09:12 - 11:40
  - 14:03 - 17:25
sessions: 2
---

# 2026-04-21 — skill_lab_diary

## Goal (오늘의 목표)
- ...

## Hypothesis (가설)
- ...

## Experiments (실험)
- config: ...
- dataset: ...
- seed: ...

## Done (실제로 한 일)
- ...

## Results (결과)
- 숫자/플롯 + 해석

## Decisions & Rationale (결정과 이유)
- ...

## Discarded / Negative Results (버린 것)
- ...

## Blockers (막힌 점)
- ...

## Next (다음 액션)
- ...
```

### 필드 규칙

- 모든 섹션은 선택적. **해당 세션에서 관련 내용이 없으면 섹션 자체를 생략** (빈 섹션 금지).
- Frontmatter 필드:
  - `date`: `YYYY-MM-DD` 형식, 작성 시점의 로컬 날짜
  - `project`: §3에서 결정된 프로젝트명
  - `server`: `hostname` 명령 결과
  - `work_hours`: 현 세션의 작업 구간 — **heuristic best-effort**. Claude가 현 대화의 첫 사용자 메시지 타임스탬프(또는 세션 jsonl 파일 mtime)를 시작으로, 일지 작성 호출 시각을 종료로 추정. 추정 불가 시 생략.
  - `sessions`: 해당 날짜에 일지를 갱신한 횟수

### 필드 의미 (브레인스토밍에서 정리된 원안 유지)

| 필드 | 목적 |
|---|---|
| Goal | 어제 세운 next step에서 1~3개 |
| Hypothesis | 오늘 검증하려 한 것 |
| Experiments | config / 데이터셋 버전 / 시드 — 재현 가능한 정보 |
| Done | 시간순 또는 주제별 bullet |
| Results | 숫자·플롯 + 해석 (해석 없으면 데이터일 뿐) |
| Decisions & Rationale | 3개월 뒤 "왜 이렇게 했지?" 방지 |
| Discarded | 안 된 접근 + 이유 (논문 limitation/future work의 원재료) |
| Blockers | 다음 날 첫 번째로 볼 항목 |
| Next | 내일 시작할 구체적 작업 |

---

## 5. Merge 동작

`/research-diary` 호출 시 동작 분기:

### Case A — 오늘 일지 없음 (최초 실행)

1. 현재 세션 대화에서 필드별 내용 추출
2. 새 파일 생성, `sessions: 1`, `work_hours`에 이번 세션 구간 하나

### Case B — 오늘 일지 이미 있음

1. **읽기**: 기존 파일 전체를 읽고 frontmatter + 각 섹션을 구조적으로 파싱
2. **분석**: 현재 세션 대화에서 추가·변경·해결된 항목을 식별
3. **추가 (기본 규칙)**: 기존 내용은 보존. 각 섹션 말미에 새 내용을 append.
   - 예: 기존 `## Done`에 bullet 3개 → 이번 세션 작업 bullet을 이어서 추가
4. **수정 제안 (사용자 확인 필수)**: 아래 상황은 Claude가 수정안을 제시하되 **사용자 승인 전까지는 반영하지 않는다**:
   - 해결된 Blocker 제거 및 Done 이동
   - 완료된 Next 항목 제거
   - 정정된 Results 값 (오전 수치가 재실행으로 바뀐 경우)
   - 기타 기존 내용과 명백히 모순되는 신규 내용
5. **제시 형식**: 변경 제안은 diff 스타일로 한 번에 모아 제시 → 사용자가 항목별 승인/거부
6. **frontmatter 갱신**: `work_hours`에 현 세션 구간 append, `sessions` 카운트 +1
7. **백업**: 덮어쓰기 전 `<today>.md.bak`로 직전 상태 보존 (안전장치). `.gitignore`에 `*.bak` 포함.

---

## 6. 플러그인 파일 구조

```
research-diary-plugin/
├── plugin.json              # Claude Code 플러그인 매니페스트
├── README.md                # 설치·설정 가이드
└── skills/
    └── research-diary/
        ├── SKILL.md                    # /research-diary 엔트리 + 실행 절차
        ├── scripts/
        │   ├── diary_setup.sh          # 로컬 repo 초기화
        │   └── diary_commit.sh         # git add/commit/push
        └── references/
            ├── diary_format.md         # 필드 템플릿 + 예시
            ├── merge_rules.md          # 상세 merge 규칙
            └── test_scenarios.md       # 수동 회귀 테스트용 시나리오 모음
```

### `SKILL.md` 핵심 내용

- `description` 프론트매터: "연구일지 작성", "하루 정리", `/research-diary` 등 트리거 키워드 포함
- **실행 절차 체크리스트** (Claude가 순서대로 수행):
  1. `$DIARY_LOCAL_PATH` 확인 → 없으면 `diary_setup.sh` 호출
  2. 프로젝트명 결정 (CWD basename 또는 `.diary-project-name`)
  3. `${DIARY_LOCAL_PATH}/<project>/<today>.md` 존재 확인 → 있으면 읽어서 merge 컨텍스트로 사용
  4. 현 세션 대화에서 필드별 내용 추출 (필요 시 `references/diary_format.md` 참조)
  5. §5 merge 규칙 적용. 수정 제안은 사용자 확인 후 반영
  6. `.bak` 백업 생성 후 파일 쓰기
  7. `diary_commit.sh <project> <date>` 호출 → git 커밋/푸시
  8. 사용자에게 요약 출력 (파일 경로, 푸시 여부, 변경 요약)

### `diary_setup.sh` 동작

- `$DIARY_LOCAL_PATH` 존재 안 함 + `$DIARY_GIT_REMOTE` 있음 → `git clone $DIARY_GIT_REMOTE $DIARY_LOCAL_PATH`
- `$DIARY_LOCAL_PATH` 존재 안 함 + `$DIARY_GIT_REMOTE` 없음 → `mkdir -p && git init` (로컬 전용)
- 이미 존재하고 git repo면 skip
- 존재하지만 git repo 아니면 exit 1 + 에러 메시지 (상위에서 사용자 확인)

### `diary_commit.sh` 동작

인자: `<project> <date>` (예: `skill_lab_diary 2026-04-21`)

- `cd $DIARY_LOCAL_PATH`
- `git add <project>/<date>.md`
- 커밋 메시지: `diary(<project>): <date>` — 간결, grep 가능
- `git push` 시도 — 실패해도 exit 0, 경고만 stderr로 출력 (로컬 쓰기는 유지)

---

## 7. 에러 처리 & 경계 조건

| 상황 | 처리 |
|---|---|
| `DIARY_LOCAL_PATH` 미설정 | 기본값 `~/research-diary` 사용 |
| `DIARY_GIT_REMOTE` 미설정 | 경고 + 로컬 전용 진행 |
| 로컬 디렉토리 없음 | `diary_setup.sh`로 자동 초기화 |
| 로컬 디렉토리 있으나 git repo 아님 | 사용자에게 `git init` 여부 확인 |
| 원격 push 실패 (네트워크/권한) | 경고만, 로컬은 유지 — 다음 실행에서 자동 재시도 |
| 현 세션에 연구 내용 거의 없음 (잡담·탐색만) | "오늘 기록할 만한 작업이 안 보이는데 그래도 생성할까요?" 확인 |
| 사용자가 merge 수정 제안 거부 | 해당 수정만 스킵, 나머지 append는 진행 |
| 기존 파일 파싱 실패 (수동 편집으로 형식 깨짐) | `.bak`로 이름 변경, 새로 작성, 사용자에게 알림 |

### 범위 밖 (v1에서 의도적으로 제외)

- 여러 프로젝트 일지 일괄 생성 (한 번 호출 = 한 프로젝트)
- 과거 날짜 소급 작성 (현재 세션 + 오늘 파일만)
- `~/.claude/projects/<hash>/*.jsonl` 직접 파싱 (Claude Code 내부 포맷 의존 리스크)
- 자동 세션 종료 훅 (v2 확장 포인트로 남김)

---

## 8. 테스트 전략

### 자동 테스트

- `scripts/diary_setup.sh`, `scripts/diary_commit.sh`는 독립 실행 가능하게 작성
- 간단한 bash 테스트 (bats 또는 수동 테스트 스크립트)로 검증:
  - clone 분기
  - init 분기
  - push 실패 시 exit code
  - 이미 있는 repo 스킵

### 수동 회귀 테스트 (merge 로직)

`references/test_scenarios.md`에 아래 시나리오 문서화:

1. 최초 생성 — 빈 프로젝트에서 첫 일지
2. 당일 append — 기존 일지에 새 Done·Results 추가
3. 당일 수정 제안 — 해결된 Blocker를 Done으로 이동 승인/거부
4. 잡담 세션 — 연구 내용 부족 시 확인 플로우
5. push 실패 — 오프라인 상태에서 로컬만 성공
6. 형식 깨진 기존 파일 — `.bak` 보존 + 재생성

Merge 로직은 Claude가 수행하므로 자동화된 유닛 테스트가 어렵다.
위 시나리오를 스킬 개발·수정 시 수동으로 돌려 회귀 확인한다.

---

## 9. 향후 확장 (Out of Scope for v1)

- **SessionEnd 훅 기반 자동 트리거**: 세션 종료 시 `/research-diary` 자동 실행 옵션 (settings.json 토글)
- **주간 요약 커맨드** (`/research-weekly`): 최근 7일 일지를 합쳐 주간 리뷰 생성
- **공유 랩 레포 모드**: 개인 repo가 아닌 연구실 공용 repo + 이름별 디렉토리로 모으는 옵션
- **논문 연동**: Discarded/Decisions 필드를 논문 limitation/future work 섹션으로 변환하는 보조 커맨드
