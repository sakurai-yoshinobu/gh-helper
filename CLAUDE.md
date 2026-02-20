# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Prerequisites

- `gh` (GitHub CLI) がインストール・認証済みであること
- SAML SSO が必要な Org では `gh auth refresh` で認可済みであること

## Architecture

- スクリプトはすべて `set -euo pipefail` で動作し、エラーで即停止
- URL パース: `https://github.com/owner/repo` → `owner/repo` を `sed` で変換
- `gh api` で GitHub REST API を直接呼び出す
- `CLAUDE.local.md` は `.gitignore` 対象（ローカル専用メモ用途）
