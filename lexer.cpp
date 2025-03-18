#include <iostream>
#include <fstream>
#include <vector>
#include <unordered_set>
#include <cctype>
using namespace std;

// 统计计数器
int keyword_count = 0;
int identifier_count = 0;
int operator_count = 0;
int delimiter_count = 0;
int string_count = 0;
int number_count = 0;
int comment_count = 0;
int error_count = 0;
int line_num = 1;

bool onlydot = false;

// 缩进栈结构
struct IndentStack {
    vector<int> stack;
    void push(int value) { stack.push_back(value); }
    int pop() { int top = stack.back(); stack.pop_back(); return top; }
    int peek() { return stack.empty() ? -1 : stack.back(); }
    void init() { stack.clear(); push(0); }
} indent_stack;

unordered_set<string> keywords = {
    "int", "float", "list", "bool", "append", "return", "print", "range",
    "pass", "break", "continue", "def", "if", "elif", "else", "class", "for", "in"
};

vector<vector<string>> operatorsByLength = {
    {">>=", "<<="},
    {"==", "!=", ">=", "<=", "+=", "-=", "*=", "/=", "%=", "&=", "|=", "^=", "->"},
    {"+", "-", "*", "/", "%", ">", "<", "=", "."}
};

unordered_set<char> delimiters = {
    ';', ',', '?', ':', '(', ')', '[', ']'
};

void handle_indent(int current_indent) {
    int top = indent_stack.peek();
    if (current_indent == top) return;
    
    if (current_indent > top) {
        cout << line_num << " <INDENT>" << endl;
        indent_stack.push(current_indent);
    } else {
        bool found = false;
        while (indent_stack.peek() > current_indent) {
            indent_stack.pop();
            cout << line_num << " <DEDENT>" << endl;
            if (indent_stack.peek() == current_indent) {
                found = true;
                break;
            }
        }
        if (!found) {
            cout << line_num << " <ERROR,indentation level does not match (fatal error and parse terminates)>" << endl;
            exit(1);
        }
    }
}

void processLine(const string& line);

int main(int argc, char* argv[]) {
    if (argc < 2) {
        cerr << "Usage: " << argv[0] << " <input_file>" << endl;
        return 1;
    }

    ifstream file(argv[1]);
    if (!file.is_open()) {
        cerr << "Error opening file" << endl;
        return 1;
    }

    indent_stack.init();
    string line;
    while (getline(file, line)) {
      
        // 处理缩进
        int indent = 0;
        while (indent < line.size() && (line[indent] == ' ' || line[indent] == '\t')) 
            indent++;
        
        // 处理全注释行
        if (line[indent] == '#') {
            comment_count++;
            cout << line_num << " <COMMENT>" << endl;
            cout << line_num << " <NEWLINE>" << endl;
            line_num++;
        }
        else{
            handle_indent(indent);
            // 处理当前行内容
            processLine(line.substr(indent));
            // \n
            cout << line_num << " <NEWLINE>" << endl;
            line_num++;
        }
    }

    while (indent_stack.peek() > 0) {
        cout << line_num << " <DEDENT>" << endl;
        indent_stack.pop();
    }

    cout << line_num << " <ENDMARKER>" << endl;

    // 输出统计信息
    cout << line_num << endl;
    cout << keyword_count << " " << identifier_count << " " 
         << operator_count << " " << delimiter_count << " "
         << string_count << " " << number_count << " "
         << comment_count << endl;
    cout << error_count;

    return 0;
}

void processString(const string& line, size_t& i) {
    size_t start = i;
    i++; // 跳过起始引号
    bool closed = false;
    while (i < line.size()) {
        if (line[i] == '"') {
            closed = true;
            break;
        }
        i++;
    }
    if (closed) {
        string_count++;
        cout << line_num << " <STRING,\"" << line.substr(start+1, i-start-1) << "\">" << endl;
        i++; // 跳过结束引号
    } else {
        error_count++;
        cout << line_num << " <ERROR,unterminated string literal:" << line.substr(start) << ">" << endl;
    }
}

void processNumber(const string& line, size_t& i) {
    size_t start = i;
    bool hasDigit = false;
    size_t intpos = -1;
    size_t dotpos = -1;
    size_t floatpos = -1;
    size_t epos = -1;
    size_t sufpos = -1;
    
    // 处理整数部分
    while (i < line.size() && isdigit(line[i])) {intpos = i; i++; hasDigit = true; }
    
    // 处理小数部分
    if (i < line.size() && line[i] == '.') {
        dotpos = i;
        i++;
        while (i < line.size() && isdigit(line[i])) {floatpos = i; i++;}
        hasDigit = true;
    }
    
    // 处理指数部分
    if (i < line.size() && (line[i] == 'e' || line[i] == 'E')) {
        epos = i;
        i++;
        if (i < line.size() && (line[i] == '+' || line[i] == '-')){ sufpos = i; i++; }
        while (i < line.size() && isdigit(line[i])){ sufpos = i; i++; }
        hasDigit = true;
    }

    
    if (hasDigit) {
        if (intpos == -1 && epos == -1 && sufpos==-1 && floatpos == -1) {i = dotpos; onlydot = true; return;} 
        if (epos != -1 && sufpos == -1) {i = epos;}
        number_count++;
        cout << line_num << " <NUMBER," << line.substr(start, i-start) << ">" << endl;
    } else {
        i = start; // 回滚
    }
}

void processOperator(const string& line, size_t& i) {
    // 尝试匹配最长可能的操作符
    for (int len=3; len>=1; len--) {
        if (i+len > line.size()) continue;
        string sub = line.substr(i, len);
        for (auto& ops : operatorsByLength) {
            for (auto& op : ops) {
                if (op == sub) {
                    operator_count++;
                    cout << line_num << " <OPERATOR," << sub << ">" << endl;
                    i += len;
                    return;
                }
            }
        }
    }
}

void processLine(const string& line) {
    size_t i = 0;
    while (i < line.size()) {
        if (line[i] == '#') { // 注释
            comment_count++;
            cout << line_num << " <COMMENT>" << endl;
            return;
        }
        if (isspace(line[i])) { i++; continue; }
        
        if (line[i] == '"') { // 字符串
            processString(line, i);
            continue;
        }

        
        if (isdigit(line[i]) || line[i] == '.') { // 数字
            processNumber(line, i);
            if(!onlydot) continue;
            else onlydot = false;
        }

        // 操作符检测
        size_t old_i = i;
        processOperator(line, i);
        if (i > old_i) continue;
        

        // 关键字/标识符
        if (isalpha(line[i]) || line[i] == '_') {
            size_t start = i;
            i++;
            while (i < line.size() && (isalnum(line[i]) || line[i] == '_')) i++;
            string word = line.substr(start, i-start);
            if (keywords.count(word)) {
                keyword_count++;
                cout << line_num << " <KEYWORD," << word << ">" << endl;
            }
            else{
                identifier_count++;
                cout << line_num << " <IDENTIFIER," << word << ">" << endl;
            }
            continue;
        }

        
        // 分隔符
        if (delimiters.count(line[i])) {
            delimiter_count++;
            cout << line_num << " <DELIMITER," << string(1, line[i]) << ">" << endl;
            i++;
            continue;
        }
        
        i++;
    }
}