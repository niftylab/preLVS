# preLVS
Routing Connectivity Verification Module for Grid-based Layout Generator

## 프로젝트 구조

이 프로젝트는 다음과 같은 디렉토리 구조를 가집니다.

* `src/preLVS_vectormerge.jl`: 메인 모듈 파일. 사용자 함수 및 내부 함수들이 정의되어 있습니다.
* `src/structs/*.jl`: 프로젝트에서 사용되는 구조체(struct) 정의 파일들이 위치합니다.
* `src/main_functions.jl`: flatten 같은 핵심 기능을 수행하는 함수 정의 파일들이 위치합니다.
* `src/utils/*.jl`: 보조적인 유틸리티 함수 정의 파일들이 위치합니다.
* `db/*.json`: 데이터베이스 관련 JSON 파일들이 위치합니다. (런타임 시 로드)
* `config/*.yaml`: 설정 관련 YAML 파일들이 위치합니다. (런타임 시 로드)
* `test/`: 벤치마크 및 테스트 관련 스크립트가 위치합니다.
* `Project.toml`: 프로젝트 의존성 및 메타데이터를 정의합니다.
* `Manifest.toml`: 정확한 의존성 버전 정보를 포함합니다 (Pkg가 관리).

## 주요 기능

* **`runLVS(input_config_file_path::String)`**: 사용자를 위한 메인 진입점 함수입니다. 설정 파일을 입력받아 전체 LVS 관련 프로세스를 실행합니다. (내부적으로 `vectorMerge` 및 연결성 분석 포함)
* **내부 함수 (벤치마크용):**
    * `loadDB()`: JSON 데이터를 로드하고 계층 구조를 처리합니다.
    * `flatten()`: `loadDB` 를 실행하고, 그 결과를 사용하여 Rect 객체들을 평탄화합니다.
    * `vectorMerge()`: `flatten`을 실행하고, 그 결과를 받아 Rect 객체들을 정렬하고 병합합니다.
* How to measure mean elapsed time of each step 
    * loading JSON DB  = @benchmark loadDB()
    * flatten function = (@benchmark flatten()) - (@benchmark loadDB())
    * processing(sort & merging) rect vector = (@benchmark vectorMerge()) - (@benchmark flatten())
    * connectivity graph generation & connectivity check = (@benchmark runLVS()) - (@benchmark vectorMerge())

## 설치 및 설정 (개발 및 벤치마킹)

1.  **Julia 설치 및 업데이트:** 시스템에 Julia (권장 버전 명시, 예: 1.6 이상)를 설치하거나 최신 버전으로 업데이트합니다.
2.  **프로젝트 클론:** 이 저장소를 로컬 컴퓨터에 복제합니다.
    ```bash
    git clone <저장소_URL>
    cd preLVS_vectormerge
    ```
3.  **Julia REPL 실행:** 프로젝트 루트 디렉토리에서 `julia`를 실행하여 REPL에 진입합니다.
    ```bash
    julia
    ```
4.  **Pkg 모드 진입:** REPL에서 `]` 키를 눌러 패키지 관리 모드로 들어갑니다. (`pkg>` 프롬프트 확인)
5.  **프로젝트 환경 활성화:** 현재 디렉토리의 `Project.toml`을 기준으로 가상 환경을 활성화합니다.
    ```julia
    pkg> activate .
    ```
    (프롬프트가 `(preLVS_vectormerge) pkg>` 와 같이 변경됩니다.)
6.  **(선택적) 의존성 해결:** `Manifest.toml`을 `Project.toml` 기준으로 업데이트합니다.
    ```julia
    pkg> resolve
    ```
7.  **의존성 설치 및 프리컴파일:** `Manifest.toml`에 명시된 모든 의존성 패키지를 다운로드/설치/빌드하고, 현재 프로젝트(`preLVS_vectormerge`)를 프리컴파일합니다.
    ```julia
    pkg> instantiate
    pkg> precompile
    ```
    (`instantiate`는 모든 의존성을 설치/빌드하고, `precompile`은 현재 프로젝트와 의존성들의 캐시 파일을 생성합니다.)
8.  **Pkg 모드 종료:** `Backspace` 키를 눌러 `julia>` 프롬프트로 돌아갑니다.
9.  **(선택적) REPL 종료:** `exit()`를 입력하여 터미널로 돌아갑니다.

## 벤치마크 실행

프로젝트 루트 디렉토리에서 다음 명령어를 실행하여 벤치마크 스크립트를 실행할 수 있습니다. (`--project=.` 플래그는 현재 디렉토리의 프로젝트 환경을 사용하도록 지정합니다.)

```bash
julia --project=. test/bench_vectormerge.jl
```
## 외부 Julia project 에서 사용

외부에서 이 모듈을 이용하고 싶다면 먼저 preLVS 모듈을 general package manager에 등록해야 한다.
```julia
pkg> dev .
julia> exit()
```
터미널에서 **--project=.** 없이 테스트벤치를 돌리면 general 환경에서도 precompile 되면서 다른 프로젝트에서도 **using** 가능
```bash
julia test/bench_vectormerge.jl
```