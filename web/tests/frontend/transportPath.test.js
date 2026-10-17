import assert from 'node:assert/strict'
import { normalizeTransportPath } from '../../src/utils/transportPath.js'

assert.equal(normalizeTransportPath('/dev-api/system/user', '/dev-api'), '/system/user')
assert.equal(normalizeTransportPath('/dev-api', '/dev-api'), '/')
assert.equal(
  normalizeTransportPath('/dev-api-other/user', '/dev-api'),
  '/dev-api-other/user'
)
assert.equal(
  normalizeTransportPath('/dev-api/system/user?page=1', '/dev-api/'),
  '/system/user'
)
assert.equal(
  normalizeTransportPath(
    'https://example.test/dev-api/system/user?page=1',
    'https://example.test/dev-api'
  ),
  '/system/user'
)
assert.equal(normalizeTransportPath('/login', ''), '/login')