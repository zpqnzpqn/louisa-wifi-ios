# 0003. Brand Identity and Repository Structure

## Status
Accepted

## Context
Initial iterations used a generic coffee cup graphic for the application icon and committed the entire repository in a single monolith commit. This made it difficult for users viewing the repository on GitHub to understand the responsibility of each folder and file, and the app lacked the instantly recognizable brand identity of Louisa Coffee.

## Decision
1. Adopt the official Louisa Coffee goddess silhouette logo (classic ivory white canvas with official orange `#F46D1E` flowing hair and black `#231F20` profile) as the primary 1024x1024 iOS App Icon.
2. Structure the repository commit history and documentation so that each top-level directory (`.github/`, `data/`, `docs/`, `LouisaWiFi/`, `scripts/`) carries its own dedicated, conventional commit description on GitHub's file browser.
3. Provide an explicit directory tour in `README.md` and maintain GitHub repository topics and metadata.
