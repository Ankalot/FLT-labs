function bloomKochAlgorithm(rules)
    io.write("--- 2nd algorithm: ---\n")
    --outputRules(rules) --для отладки
    --coming soon
end

function concatRules(ruleLeft, ruleRight)
    local rule = {}
    local i = 1
    for _, val in ipairs(ruleLeft) do
        rule[i] = val
        i = i + 1
    end
    for _, val in ipairs(ruleRight) do
        rule[i] = val
        i = i + 1
    end
    return rule
end

function findNtermByOrder(i, ntermsLexOrd)
    for nterm, ord in pairs(ntermsLexOrd) do
        if (ord == i) then
            return nterm
        end
    end
end

function makeNewNterm(rules)
    local newNterm
    while true do
        newNterm = ""
        for i = 1, math.random(1, 5) do
            newNterm = newNterm .. string.char(math.random(65, 90))
        end
        if not rules[newNterm] then
            break
        end
    end
    return newNterm
end

function findNumElemsInTbl(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function ruleIsLeftRec(rule, nterm) 
    return type(rule[1]) == "table" and rule[1][1] == nterm
end

function useNtermsLexOrd(rules, ntermsLexOrd)
    local ntermsNum = findNumElemsInTbl(rules)
    local newNtermCounter = 0
    for i = 1, ntermsNum, 1 do
        local nterm = findNtermByOrder(i, ntermsLexOrd)
        local ntermRules = rules[nterm]

        local j = 1
        local ntermRulesNum = #ntermRules
        local leftRecRules = {}
        while (j <= ntermRulesNum) do
            local rule = ntermRules[j]
            if (type(rule[1]) == "table") then
                local locNterm = rule[1][1]
                if (ntermsLexOrd[nterm] > ntermsLexOrd[locNterm]) then
                    table.remove(ntermRules, j)
                    table.remove(rule, 1)
                    for _, locRule in ipairs(rules[locNterm]) do
                        table.insert(ntermRules, concatRules(locRule, rule))
                    end
                    ntermRulesNum = ntermRulesNum - 1 + #rules[locNterm]                   
                else
                    if (ntermsLexOrd[nterm] == ntermsLexOrd[locNterm]) then
                        table.insert(leftRecRules, rule)
                    end
                    j = j + 1
                end
            else
                j = j + 1
            end
        end

        if (#leftRecRules ~= 0) then
            local newNterm = makeNewNterm(rules)
            newNtermCounter = newNtermCounter + 1
            ntermsLexOrd[newNterm] = -newNtermCounter + 1
            rules[newNterm] = {}
            local i = 1
            local prevNtermRulesCount = #ntermRules
            while (i <= prevNtermRulesCount) do
                if ruleIsLeftRec(ntermRules[i], nterm) then
                    table.remove(ntermRules, i)
                    prevNtermRulesCount = prevNtermRulesCount - 1 
                else
                    table.insert(ntermRules, concatRules(ntermRules[i], {{newNterm}}))
                    for _, leftRecRule in ipairs(leftRecRules) do
                        table.insert(rules[newNterm], leftRecRule)
                        table.insert(rules[newNterm], concatRules(leftRecRule, {{newNterm}}))
                    end 
                    i = i + 1
                end
            end
        end
    end

    for nterm, _ in pairs(ntermsLexOrd) do
        ntermsLexOrd[nterm] = ntermsLexOrd[nterm] + newNtermCounter
    end
end

function outputNtermsLexOrd(ntermsLexOrd)
    io.write("--- Partial order of non-terminals: ---\n")
    for term, i in pairs(ntermsLexOrd) do
        io.write(term..": "..i.."\n")
    end
    io.write("\n")
end

function makeNtermsLexOrd(nterm, rules, ntermsLexOrd, counter)
    ntermsLexOrd[nterm] = counter[1]
    counter[1] = counter[1] + 1 -- counter должен быть числом, но тк только таблицы
    -- передаются по ссылке, то пришлось упаковать его в таблицу (костыль типа)
    for _, rule in ipairs(rules[nterm]) do
        for _, smth in ipairs(rule) do
            if (type(smth) == "table") then
                local LocNterm = smth[1]
                if (not ntermsLexOrd[LocNterm]) then
                    makeNtermsLexOrd(LocNterm, rules, ntermsLexOrd, counter)
                end
            end
        end
    end
end

function leftRuleSweep(rules)
    for nterm, ntermRules in pairs(rules) do
        local i = 1
        local ntermRulesNum = #ntermRules
        while (i <= ntermRulesNum) do
            local rule = ntermRules[i]
            if (type(rule[1]) == "table") then
                local locNterm = rule[1][1]
                table.remove(ntermRules, i)
                table.remove(rule, 1)
                for _, locRule in ipairs(rules[locNterm]) do
                    table.insert(ntermRules, concatRules(locRule, rule))
                end
                ntermRulesNum = ntermRulesNum - 1 + #rules[locNterm]
            else
                i = i + 1
            end
        end
    end
end

function leftRecAlgorithm(rules)
    io.write("--- 1st algorithm: ---\n")
    local ntermsLexOrd = {}
    makeNtermsLexOrd("S", rules, ntermsLexOrd, {1})
    useNtermsLexOrd(rules, ntermsLexOrd)
    leftRuleSweep(rules)
    outputNtermsLexOrd(ntermsLexOrd)
    outputRules(rules)
end

function outputRules(rules)
    io.write("--- Rules: ---\n")
    for nterm, ntermRules in pairs(rules) do
        io.write("["..nterm.."] -> ")
        for i, rule in ipairs(ntermRules) do
            for _, smth in ipairs(rule) do
                if (type(smth) == "table") then
                    io.write("["..smth[1].."]")
                else
                    io.write(smth)
                end
            end
            if (i ~= #ntermRules) then
                io.write(" | ")
            end
        end
        io.write("\n")
    end
    io.write("\n")
end

function inputRules()
    local rules = {}
    for line in io.lines() do
        local first, last = 0, 0
        first, last = line:find("%[%a+%d*%]", 0)
        local startNterm = line:sub(first + 1, last - 1)
        if not rules[startNterm] then
           rules[startNterm] = {} 
        end
        local rule = {}

        first, last = line:find("->", last + 1)
        while true do
            first, last = line:find("[%[|%a|%d]", last + 1)
            if not first then break end
            local term = line:sub(first, last)
            if term == "[" then
                first, last = line:find("%a+%d*%]", first + 1)
                local nterm = line:sub(first, last - 1)
                table.insert(rule, {nterm})
            else
                table.insert(rule, term)
            end
        end
        table.insert(rules[startNterm], rule)
    end
    return rules
end

function copy(obj, seen)
    if type(obj) ~= 'table' then
        return obj
    end
    if seen and seen[obj] then
        return seen[obj]
    end
    local s = seen or {}
    local res = setmetatable({}, getmetatable(obj))
    s[obj] = res
    for k, v in pairs(obj) do
        res[copy(k, s)] = copy(v, s)
    end
    return res
end

function main()
    local rules = inputRules()
    local rulesCopy = copy(rules)
    leftRecAlgorithm(rules)
    bloomKochAlgorithm(rulesCopy)
end

main()