# research-diary-plugin

Claude Code 세션 대화에서 **구조화된 연구일지**를 자동으로 작성하고, 각 프로젝트 안의 `research-diary/` 디렉토리에 날짜별로 저장하는 플러그인. 연구실 공동 배포용.

**핵심 디자인**
- 각 프로젝트가 자신만의 `research-diary/` 디렉토리를 갖는 **per-project 격리**
- `research-diary/`는 프로젝트의 git과 분리된 nested git repo
- 필드 구조: Goal / Hypothesis / Experiments / Done / Results / Decisions & Rationale / Discarded / Blockers / Next
- 옵션: 연구실 공통 레포 하나에 프로젝트별 브랜치로 자동 push

---

## Quick Start

```bash
# 1. 설치 (한 번)
/plugin marketplace add apple4ree/skill_lab_diary
/plugin install research-diary-plugin@skill_lab_diary
/reload-plugins

# 2. 아무 연구 프로젝트에서
cd ~/my-research-project
claude
> ... 연구 작업 수행 ...
> /research-diary
```

첫 호출 시 `./research-diary/` 디렉토리가 자동 생성되고 `git init`된 뒤 오늘자 일지 파일이 작성됩니다. 설정 파일 편집 없이 바로 사용 가능.

---

## Install

이 레포는 single-plugin marketplace 구조입니다. 두 단계로 설치:

```
/plugin marketplace add apple4ree/skill_lab_diary
/plugin install research-diary-plugin@skill_lab_diary
/reload-plugins
```

**주의**: `marketplace add` 인자는 `owner/repo` 형식 (`github:` 접두사 없이).

업데이트:

```
/plugin marketplace update skill_lab_diary
/plugin install research-diary-plugin@skill_lab_diary
/reload-plugins
```

---

## 일상 사용

### 처음 쓰는 날

```
$ cd ~/my-project
$ claude
> ... 하루 동안 연구/개발 작업 ...
> /research-diary
```

Claude가 수행:
1. 현 세션 대화를 훑어 필드별로 내용 추출
2. `./research-diary/` 디렉토리 생성 + `git init`
3. `./research-diary/YYYY-MM-DD.md` 파일 작성
4. 로컬 커밋 (`diary: YYYY-MM-DD`)
5. `DIARY_REMOTE_URL`이 설정되어 있으면 원격에 push

### 같은 날 다시 호출 (오후 세션 등)

```
> /research-diary
```

기존 일지를 읽고 **merge**:
- 신규 내용은 각 섹션 말미에 append (기존 내용 보존)
- 기존 내용 수정이 필요해 보이는 항목(해결된 Blocker, 완료된 Next, 정정된 Results 등)은 **diff 형태로 제시하고 사용자 승인 후에만 적용**
- 덮어쓰기 전 `YYYY-MM-DD.md.bak` 자동 백업 (diary 레포의 `.gitignore`에서 제외됨)

### 다른 프로젝트로 이동

```
$ cd ~/other-project
$ claude
> /research-diary
```

완전히 새로운 `./research-diary/` nested 레포가 해당 프로젝트 안에 생성됩니다. 이전 프로젝트의 일지와 완전히 분리됨.

---

## 구성 (선택사항)

플러그인은 기본적으로 **설정 없이도 동작**합니다. 로컬 전용으로 쓰신다면 이 섹션은 건너뛰어도 됩니다.

### 옵션 1: 연구실 공통 레포에 자동 push (추천)

`~/.claude/settings.json`에 다음 한 줄 추가:

```json
{
  "env": {
    "DIARY_REMOTE_URL": "git@github.com:<your-lab>/research-diary.git"
  }
}
```

동작:
- 새 프로젝트에서 `/research-diary` 첫 호출 시 자동으로:
  - `./research-diary/` 생성 + `git init -b <프로젝트명>`
  - `git remote add origin <DIARY_REMOTE_URL>`
  - 일지 작성 + 커밋 + `git push origin <프로젝트명>`
- 결과: **한 GitHub 레포에 프로젝트별 브랜치로 누적**
- 브랜치 이름 = `basename $(pwd)` (또는 프로젝트 루트에 `.diary-project-name` 파일이 있으면 그 내용)
- 특정 프로젝트 일지 조회: `git checkout <프로젝트명>`

Push 실패는 non-fatal — 네트워크 끊겨도 로컬 커밋은 무조건 성공, 다음 호출 때 재시도.

### 옵션 2: 프로젝트별로 수동 remote 설정

`DIARY_REMOTE_URL` 없이 프로젝트마다 개별 GitHub repo를 쓰고 싶을 때:

```bash
cd research-diary
git remote add origin git@github.com:<you>/<project>-diary.git
git push -u origin main
```

한 번 등록하면 그 프로젝트의 이후 `/research-diary` 호출은 자동 push.

### `.diary-project-name` 파일

프로젝트 디렉토리 이름과 원하는 브랜치/라벨 이름이 다를 때 프로젝트 루트에 이 파일을 두면:

```bash
echo "my-clean-project-name" > .diary-project-name
```

- 일지 frontmatter의 `project` 필드에 반영
- `DIARY_REMOTE_URL` 모드에서 git 브랜치 이름으로 사용

---

## 일지 파일 구조

`./research-diary/YYYY-MM-DD.md`:

```markdown
---
date: 2026-04-21
project: my-project
server: my-workstation
work_hours:
  - 14:03 - 17:25
sessions: 1
---

# 2026-04-21 — my-project

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

**규칙**: 비어 있는 섹션은 파일에서 생략됩니다 (`- (none)` 같은 플레이스홀더 금지). 전체 스키마는 `plugin/skills/research-diary/references/diary_format.md` 참고.

---

## 동작 상세

### 디렉토리 구조 (사용자 입장)

```
~/project-A/
├── <프로젝트 소스>
└── research-diary/       ← 이 프로젝트의 일지들이 쌓임 (nested git repo)
    ├── .git/
    ├── 2026-04-21.md
    ├── 2026-04-22.md
    └── ...

~/project-B/
├── <프로젝트 소스>
└── research-diary/       ← 완전히 독립된 별개의 nested git repo
    ├── .git/
    └── 2026-04-21.md
```

프로젝트 루트가 git repo라면 `research-diary/`는 상위 git 입장에서 **untracked nested repo**로 보입니다. 숨기고 싶으면 프로젝트의 `.gitignore`에 `research-diary/` 추가.

### 환경 변수 요약

| 변수 | 기본값 | 역할 |
|---|---|---|
| `DIARY_REMOTE_URL` | (미설정) | 설정 시 모든 프로젝트의 diary repo에 자동으로 이 URL을 origin으로 등록. 프로젝트별 브랜치로 push |
| `DIARY_LOCAL_PATH` | `$(pwd)/research-diary` | diary 디렉토리 경로 override (보통 불필요 — 테스트/특수 상황용) |

### 트리거 조건

Claude가 `/research-diary` 스킬을 활성화하는 조건:
- 슬래시 커맨드: `/research-diary`
- 자연어: "연구일지 써줘", "하루 정리해줘", "write today's research log", "update my diary" 등

---

## 트러블슈팅

**Q. `/plugin install`에서 "Marketplace not found"**
→ `/plugin marketplace add apple4ree/skill_lab_diary` 먼저 실행 (단일 명령이 아닌 2단계).

**Q. settings.json에서 `DIARY_REMOTE_URL` 고쳤는데 반영 안 됨**
→ Claude Code 프로세스 env는 시작 시점에 고정됩니다. 재시작 필요.

**Q. `research-diary/ exists but isn't a git repository` 에러**
→ `./research-diary/` 디렉토리가 이미 있는데 `.git/`이 없는 상태. 수동으로 `rm -rf research-diary/` 하거나 `cd research-diary && git init`.

**Q. Push가 실패함**
→ 로컬 커밋은 성공. 다음 `/research-diary` 호출 시 쌓인 커밋들이 함께 재전송됩니다. 원격 reachability 확인 후 재시도.

**Q. 어제 일지를 수정하고 싶다**
→ 그냥 직접 `./research-diary/2026-04-20.md` 편집 → `cd research-diary && git commit -am "fix: yesterday"`. 플러그인은 오늘 날짜 파일만 건드립니다.

---

## 개발

### 테스트 실행

```bash
bash tests/run_tests.sh
```

shell 스크립트 2개(`diary_setup.sh`, `diary_commit.sh`) 대한 유닛 테스트 9개. Merge 로직은 Claude 런타임이 담당해서 수동 회귀 시나리오로 검증 (`plugin/skills/research-diary/references/test_scenarios.md`).

### 레이아웃

```
.
├── .claude-plugin/marketplace.json   # marketplace 인덱스
├── plugin/                           # 플러그인 본체
│   ├── .claude-plugin/plugin.json    # 플러그인 매니페스트
│   └── skills/research-diary/
│       ├── SKILL.md                  # /research-diary 오케스트레이션
│       ├── scripts/
│       │   ├── diary_setup.sh        # diary 디렉토리 초기화 (init + optional remote/branch)
│       │   └── diary_commit.sh       # 커밋 + 원격 push (push 실패 tolerate)
│       └── references/
│           ├── diary_format.md       # 필드 스키마 상세
│           ├── merge_rules.md        # 당일 재호출 merge 규칙
│           └── test_scenarios.md     # 수동 회귀 시나리오
├── tests/                            # bash 테스트 하네스
├── docs/superpowers/{specs,plans}/   # 설계 및 구현 계획 문서
└── README.md
```

### 버전 히스토리

- **v0.1.0**: 중앙 repo 모델 (`~/research-diary/<project>/<date>.md`)
- **v0.2.0** (breaking): per-project 격리 — 각 프로젝트 안에 nested repo
- **v0.3.0**: 옵션 `DIARY_REMOTE_URL` 추가 — 모든 프로젝트가 공통 레포의 프로젝트별 브랜치로 자동 push

---

## License

TBD by the lab.
