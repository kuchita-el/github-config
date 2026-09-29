# terraform-design-reviewer 観点 9 の入力「## 非推奨スキーマ一覧」を作る抽出。
#
# 入力: `terraform providers schema -json` の出力（標準入力）
# 引数: --rawfile types <ファイル>
#   差分が触れた .tf ファイル（PR 適用後）にある resource・data source の型の一覧。
#   1行に「resource <TYPE>」または「data <TYPE>」を1つ書く（空行は無視する）。
# 出力: 次の3つのキーを持つ JSON オブジェクト（形式の定めは reviewer 定義の「入力」節）
#   checked    : 照合した型（引数の一覧のうち、provider schema に見つかったもの）
#   not_found  : provider schema に見つからなかった型
#   deprecated : checked の型にある非推奨の印（deprecated: true）の一覧
#
# 使い方（README「PR レビュー時の reviewer 併用」節）:
#   jq --rawfile types /tmp/tf-types.txt \
#     -f docs/agents/terraform-design-reviewer/extract-deprecations.jq \
#     /tmp/tf-schema.json > /tmp/tf-deprecations.json

def join_path($prefix; $name):
  if $prefix == "" then $name else "\($prefix).\($name)" end;

# 属性の集まり（attributes）を走査する。nested_type を持つ属性は、その中の属性も走査する。
def attrs($prefix):
  (. // {}) | to_entries[]
  | .key as $name
  | .value as $attr
  | join_path($prefix; $name) as $path
  | (
      (if $attr.deprecated == true
       then {target: "attribute", path: $path}
       else empty end),
      (($attr.nested_type.attributes // null) | if . == null then empty else attrs($path) end)
    );

# block を走査する。$prefix が空のときは型の最上位の block（型自体の非推奨は呼び出し側で扱う）。
def blk($prefix):
  . as $block
  | (
      (if $prefix != "" and $block.deprecated == true
       then {target: "block", path: $prefix}
       else empty end),
      ($block.attributes | attrs($prefix)),
      (($block.block_types // {}) | to_entries[]
        | join_path($prefix; .key) as $path
        | .value.block | blk($path))
    );

($types
  | split("\n")
  | map(gsub("^\\s+|\\s+$"; "") | select(length > 0) | split(" ") | map(select(length > 0))
        | {kind: .[0], type: .[1]})
  | unique_by([.kind, .type])) as $wanted
| [.provider_schemas[]] as $providers
| [ $wanted[]
    | . as $w
    | (if $w.kind == "data" then "data_source_schemas" else "resource_schemas" end) as $key
    | {kind: $w.kind, type: $w.type,
       schema: ([$providers[] | .[$key] // {} | .[$w.type] // empty] | first)}
  ] as $found
| {
    checked:   [$found[] | select(.schema != null) | {kind, type}],
    not_found: [$found[] | select(.schema == null) | {kind, type}],
    deprecated: [
      $found[] | select(.schema != null)
      | {kind, type} as $t
      | .schema.block
      | (
          (if .deprecated == true
           then {target: "type", path: ""}
           else empty end),
          blk("")
        )
      | $t + .
    ]
  }
