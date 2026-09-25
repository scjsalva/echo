import { describe, expect, it } from 'vitest'
import { buildFileTree } from './fileTree'

describe('buildFileTree', () => {
  it('nests files by folder, folders first, and merges single-folder chains', () => {
    const tree = buildFileTree([{ path: 'README.md' }, { path: 'app/models/user.rb' }, { path: 'app/models/team.rb' }, { path: 'app/views/users/show.haml' }])

    expect(tree.map((n) => n.name)).toEqual(['app', 'README.md'])
    const app = tree[0]
    if (app.kind !== 'dir') throw new Error('expected a folder')
    expect(app.children.map((n) => n.name)).toEqual(['models', 'views/users'])
    const models = app.children[0]
    if (models.kind !== 'dir') throw new Error('expected a folder')
    expect(models.children.map((n) => n.path)).toEqual(['app/models/team.rb', 'app/models/user.rb'])
  })
})
