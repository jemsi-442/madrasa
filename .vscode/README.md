# Source Control in This Workspace

When opening the project root in VS Code, use the root repository as the editor's
single source-control view. It already tracks backend source, Prisma migrations,
tests, and the Flutter frontend. The nested backend repository covers many of the
same files, so displaying both repositories creates overlapping status providers.

`settings.json` excludes only the nested repository from VS Code discovery. It
does not ignore backend source files in Git, disable file decorations, delete
either repository, or change commit history. Git autorefresh remains enabled.
Generated backend `dist/`, `node_modules/`, and local `.env` files are ignored by
both repositories and remain available on disk.

After applying this setting to an already-open window, run **Developer: Reload
Window** once from the Command Palette. The installed Git extension checks
`git.ignoredRepositories` when opening repositories; the setting does not close
a repository that was already opened. Source Control should then show only the
root repository for this workspace. New edits to backend source will still show
as changes there.

The backend repository still exists for command-line history. Until it is
deliberately consolidated, backend stages must be committed in both repositories:

```sh
git status --short --untracked-files=all
git -C backend status --short --untracked-files=all
```

Empty output means no uncommitted changes in that repository. Local commits do
not imply a push to a remote. If badges remain after reloading with this setting,
check the Git output log before changing files or clearing editor state.
