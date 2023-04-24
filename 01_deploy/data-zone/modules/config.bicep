/** 
** Configuration module
**/
param prefix string
param project string
param env string


var name = '${prefix}${project}${env}'

output names object = {
  storage : '${name}stg'
}
