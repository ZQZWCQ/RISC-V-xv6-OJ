import request from '@/utils/request'

// 根据字典类型查询选项，供业务页面使用
export function getDicts(dictType) {
  return request({
    url: '/system/dict/data/type/' + dictType,
    method: 'get',
  })
}