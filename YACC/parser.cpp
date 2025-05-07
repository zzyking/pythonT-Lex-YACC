#include <iostream>
#include <vector>
#include <stack>
#include <map>
#include <string>
#include <fstream>
#include <sstream>
#include <set>
//如果需要更多头文件，可自行补充

using namespace std;

struct Token {
    string type;
    string value;
    Token(string t, string v) : type(t), value(v) {}
};

vector<Token> lex(const string& input) {
    vector<Token> tokens;
    size_t pos = 0;
    size_t len = input.size();

    while (pos < len) {
        char c = input[pos];
        if (isspace(c) && c != '\n') {
            pos++;
            continue;
        }
        if (c == '\n') {
            tokens.emplace_back("NEWLINE", "NEWLINE");
            pos++;
            continue;
        }
        if (c == '"') {
            size_t start = pos++;
            while (pos < len && input[pos] != '"') pos++;
            if (pos < len) {
                tokens.emplace_back("STR", input.substr(start, pos - start + 1));
                pos++;
            } else {
                tokens.emplace_back("STR", input.substr(start, pos - start));
            }
            continue;
        }
        if (isalpha(c)) {
            size_t start = pos++;
            while (pos < len && (isalnum(input[pos]) || input[pos] == '_')) pos++;
            string val = input.substr(start, pos - start);
            tokens.emplace_back(val == "print" ? "PRINT" : "ID", val);
            continue;
        }
        switch (c) {
            case ';': tokens.emplace_back(";", ";"); break;
            case '(': tokens.emplace_back("(", "("); break;
            case ')': tokens.emplace_back(")", ")"); break;
            case ',': tokens.emplace_back(",", ","); break;
            default: tokens.emplace_back("UNKNOWN", string(1, c)); break;
        }
        pos++;
    }

    if (!tokens.empty() && tokens.back().type != "NEWLINE") tokens.emplace_back("NEWLINE", "NEWLINE");
    tokens.emplace_back("ENDMARKER", "ENDMARKER");
    return tokens;
}

class LRParser {
    const vector<pair<string, vector<string>>> productions = {
        {"file", {"statements", "ENDMARKER"}},
        {"statements", {"statements", "statement"}},
        {"statements", {}},
        {"statement", {"simple_stmts"}},
        {"simple_stmts", {"simple_stmt_list", "NEWLINE"}},
        {"simple_stmt_list", {"simple_stmt"}},
        {"simple_stmt_list", {"simple_stmt_list", ";", "simple_stmt"}},
        {"simple_stmt", {"print_stmt"}},
        {"print_stmt", {"PRINT", "(", "args", ")"}},
        {"args", {"arg"}},
        {"args", {"args", ",", "arg"}},
        {"arg", {"STR"}}
    };

    map<pair<int, string>, string> actionTable;
    map<pair<int, string>, int> gotoTable;

    void initTables() {
        actionTable[{0, "PRINT"}] = "reduce 2";
        actionTable[{0, "ENDMARKER"}] = "reduce 2";

        actionTable[{1, "ENDMARKER"}] = "accept";

        actionTable[{2, "ENDMARKER"}] = "shift 1";
        actionTable[{2, "PRINT"}] = "shift 8";

        actionTable[{3, "ENDMARKER"}] = "reduce 1";
        actionTable[{3, "PRINT"}] = "reduce 1";

        actionTable[{4, "ENDMARKER"}] = "reduce 3";
        actionTable[{4, "PRINT"}] = "reduce 3";

        actionTable[{5, "NEWLINE"}] = "shift 9";
        actionTable[{5, ";"}] = "shift 10";

        actionTable[{6, "NEWLINE"}] = "reduce 5";
        actionTable[{6, ";"}] = "reduce 5";

        actionTable[{7, "NEWLINE"}] = "reduce 7";
        actionTable[{7, ";"}] = "reduce 7";

        actionTable[{8, "("}] = "shift 11";

        actionTable[{9, "ENDMARKER"}] = "reduce 4";
        actionTable[{9, "PRINT"}] = "reduce 4";

        actionTable[{10, "PRINT"}] = "shift 8";

        actionTable[{11, "STR"}] = "shift 15";

        actionTable[{12, "NEWLINE"}] = "reduce 6";
        actionTable[{12, ";"}] = "reduce 6";

        actionTable[{13, ")"}] = "shift 16";
        actionTable[{13, ","}] = "shift 17";

        actionTable[{14, ")"}] = "reduce 9";
        actionTable[{14, ","}] = "reduce 9";

        actionTable[{15, ")"}] = "reduce 11";
        actionTable[{15, ","}] = "reduce 11";

        actionTable[{16, "NEWLINE"}] = "reduce 8";
        actionTable[{16, ";"}] = "reduce 8";

        actionTable[{17, "STR"}] = "shift 15";

        actionTable[{18, ")"}] = "reduce 10";
        actionTable[{18, ","}] = "reduce 10";

        gotoTable[{0, "statements"}] = 2;
        gotoTable[{2, "statement"}] = 3;
        gotoTable[{2, "simple_stmts"}] = 4;
        gotoTable[{2, "simple_stmt_list"}] = 5;
        gotoTable[{2, "simple_stmt"}] = 6;
        gotoTable[{2, "print_stmt"}] = 7;

        gotoTable[{10, "simple_stmt"}] = 12;
        gotoTable[{10, "print_stmt"}] = 7;

        gotoTable[{11, "args"}] = 13;
        gotoTable[{11, "arg"}] = 14;
        gotoTable[{17, "arg"}] = 18;
    }

    public:
    vector<Token> tokens;
    size_t current = 0;
    stack<int> states;
    stack<string> symbols;

    LRParser(vector<Token> t) : tokens(t) {
        initTables();
        states.push(0);
    }

    void parse() {
        while (true) {
            int state = states.top();
            string token = current < tokens.size() ? tokens[current].type : "ENDMARKER";
            string tokenVal = current < tokens.size() ? tokens[current].value : "EOF";

            auto act = actionTable.find({state, token});
            if (act == actionTable.end()) {
                cout << "syntax error at : " << tokenVal << endl;
                // 恐慌模式：跳过直到找到能继续解析的 token
                while (current < tokens.size()) {
                    cout << "skipping : " << tokens[current].value << endl;
                    current++;
                    if (current < tokens.size()) {
                        token = tokens[current].type;
                        tokenVal = tokens[current].value;
                        act = actionTable.find({states.top(), token});
                        if (act != actionTable.end()) {
                            cout << "resuming parsing at : " << tokenVal << endl;
                            break;
                        }
                    }
                }
                if (current >= tokens.size()) {
                    cerr << "无法恢复解析，提前结束。" << endl;
                    return;
                }
            } else {
                string action = act->second;

                if (action.rfind("shift", 0) == 0) {
                    int newState = stoi(action.substr(6));
                    cout << "shift : " << tokenVal << endl;
                    symbols.push(token);
                    states.push(newState);
                    current++;
                } else if (action.rfind("reduce", 0) == 0) {
                    int prodNum = stoi(action.substr(7));
                    auto& prod = productions[prodNum];
                    cout << "reduce by " << prod.first << " -> ";
                    if (prod.second.empty()) {
                        cout << "empty";
                    } else {
                        for (size_t i = 0; i < prod.second.size(); ++i) {
                            if (i > 0) cout << " ";
                            cout << prod.second[i];
                        }
                    }
                    cout << endl;

                    for (size_t i = 0; i < prod.second.size(); ++i) {
                        if (!symbols.empty()) symbols.pop();
                        if (!states.empty()) states.pop();
                    }

                    string lhs = prod.first;
                    int prevState = states.top();
                    symbols.push(lhs);

                    auto gt = gotoTable.find({prevState, lhs});
                    if (gt == gotoTable.end()) {
                        cerr << "语法错误：缺少 GOTO[" << prevState << ", " << lhs << "]" << endl;
                        return;
                    }
                    states.push(gt->second);
                } else if (action == "accept") {
                    cout << "reduce by file -> statements ENDMARKER" << endl;
                    cout << "accept";
                    return;
                }
            }
        }
    }
};

//主函数要求以文件形式读入。下述示例程序可替换。
int main(int argc, char **argv) {
    ifstream in_file(argv[1]);
    if (!in_file) {
        cerr << "无法打开文件！" << endl;
        return 1;
    }

    stringstream buffer;
    buffer << in_file.rdbuf();
    string input = buffer.str();
    
    auto tokens = lex(input);
    LRParser parser(tokens);
    parser.parse();
    
    return 0;
}
