const ast = @import("ast.zig");
const sub_parser = @import("sub_parser.zig");
const SubParser = sub_parser.SubParser;
const TokenAndStateList = ast.TokenAndStateList;

pub const NextLinker = struct {
    tokens: TokenAndStateList,
    subParser: SubParser,

    /// levelParserの仕組みをどうするか
    /// レベルはmatchingの深さを表す
    /// 例えばto ~ でマッチする構文が二つある際には、lv0の時ははじめにマッチする物
    /// lv1の時は二つ目のマッチする物を選ぶ 内部にmatch変数を作り、パーサーにあたるたびにmatchをインクリメント
    /// lv0の時はmatchが0のもの、lv1の時はmatchが1のものを選ぶ
    fn parser(self: *NextLinker, level: u4) !void {
        _ = level;
        _ = self;
    }
};
