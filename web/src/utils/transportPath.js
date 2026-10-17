/**
 * 标准化实际请求路径，供传输加密策略匹配和 AAD 校验共用。
 *
 * @param {string} url 请求地址
 * @param {string} baseApi API 基础地址
 * @returns {string} 标准化请求路径
 */
export function normalizeTransportPath(url = '', baseApi = '') {
  const raw = String(url || '')
  let pathname = /^https?:\/\//.test(raw)
    ? new URL(raw).pathname
    : raw.split('?')[0] || '/'

  const basePath = /^https?:\/\//.test(baseApi)
    ? new URL(baseApi).pathname
    : baseApi

  const normalizedBase = basePath.replace(/\/$/, '')

  if (
    normalizedBase &&
    (pathname === normalizedBase || pathname.startsWith(`${normalizedBase}/`))
  ) {
    pathname = pathname.slice(normalizedBase.length)
  }

  return pathname || '/'
}