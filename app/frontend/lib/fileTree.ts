export interface TreeFile<T> {
  kind: 'file'
  name: string
  path: string
  file: T
}
export interface TreeDir<T> {
  kind: 'dir'
  name: string
  path: string
  children: TreeNode<T>[]
}
export type TreeNode<T> = TreeFile<T> | TreeDir<T>

/**
 * Nests files by folder, folders first, both sorted by name. A folder with a
 * single subfolder and nothing else is shown as one row ("app/models"), as on GitHub.
 */
export function buildFileTree<T extends { path: string }>(files: T[]): TreeNode<T>[] {
  const root: TreeDir<T> = { kind: 'dir', name: '', path: '', children: [] }

  for (const file of files) {
    const parts = file.path.split('/')
    let dir = root
    parts.slice(0, -1).forEach((name, i) => {
      const path = parts.slice(0, i + 1).join('/')
      let next = dir.children.find((c): c is TreeDir<T> => c.kind === 'dir' && c.name === name)
      if (!next) dir.children.push((next = { kind: 'dir', name, path, children: [] }))
      dir = next
    })
    dir.children.push({ kind: 'file', name: parts.at(-1)!, path: file.path, file })
  }

  return tidy(root).children
}

function tidy<T>(dir: TreeDir<T>): TreeDir<T> {
  dir.children = dir.children
    .map((child) => {
      if (child.kind === 'file') return child
      let merged = tidy(child)
      while (merged.children.length === 1 && merged.children[0].kind === 'dir') {
        const only = merged.children[0]
        merged = { ...only, name: `${merged.name}/${only.name}` }
      }
      return merged
    })
    .sort((a, b) => (a.kind === b.kind ? a.name.localeCompare(b.name) : a.kind === 'dir' ? -1 : 1))
  return dir
}
