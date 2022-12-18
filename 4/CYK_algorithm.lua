function makeParseTreeHRight(next, hright)
    if type(hright) == "string" then
        table.insert(next, hright)
    else
        table.insert(next, makeParseTree(hright))
    end
end

function makeParseTreeHLeft(next, hleft)
    if hleft.left then
        makeParseTreeHLeft(next, hleft.left)
    end
    if hleft.right then
        makeParseTreeHRight(next, hleft.right)
    end
end

function makeParseTree(a)
    local parseTree = {}
    
    parseTree.nterm = a.nterm
    parseTree.next = {}
    if a.term then
        table.insert(parseTree.next, a.term)
    else
        local h = a.h
        if h.left then
            makeParseTreeHLeft(parseTree.next, h.left)
        end
        if h.right then
            makeParseTreeHRight(parseTree.next, h.right)
        end
    end

    return parseTree
end

function CYKalgorithm(rules, startNterm, str)
    -- Алгоритм Кока-Янгера-Касами, модификация для произвольной кс грамматики и 
    --     с запоминанием левостороннего произвольного дерева разбора

    -- a[nterm][i][j].bool == (A ->* str:sub(i, j-1))
    -- h[rule][i][j][k].bool == (префикс длины k из rule ->* str:sub(i, j-1))

    -- создание массивов:
    local n = string.len(str)
    local a, h = {}, {}
    for nterm, ntermRules in pairs(rules) do
        local x = {}
        a[nterm] = x
        for i = 1, n + 1 do
            local y = {}
            x[i] = y
            for j = 1, n + 1 do
                y[j] = {bool = false, nterm = nterm}
            end
        end

        for _, rule in ipairs(ntermRules) do
            local z = {}
            h[rule] = z
            for i = 1, n + 1 do
                local g = {}
                z[i] = g
                for j = 1, n + 1 do
                    local e = {}
                    g[j] = e
                    for k = 0, #rule do
                        e[k] = {bool = false}
                    end
                end
            end
        end
    end

    -- база динамики:
    for i = 1, n + 1 do
        for nterm, ntermRules in pairs(rules) do
            for _, rule in ipairs(ntermRules) do
                if #rule == 0 then
                    a[nterm][i][i].bool = true
                end 
                if i ~= n + 1 then
                    if (#rule == 1) and (type(rule[1]) == "string") and (rule[1] == str:sub(i, i)) then
                        a[nterm][i][i+1].bool = true
                        a[nterm][i][i+1].nterm = nterm
                        a[nterm][i][i+1].term = rule[1]
                    end
                end
                h[rule][i][i][0].bool = true
            end
        end
    end

    -- переход:
    for m = 0, n do
        for i = 1, n do
            local j = i + m
            if j <= n + 1 then
                for nterm, ntermRules in pairs(rules) do
                    for _, rule in ipairs(ntermRules) do
                        for k = 1, #rule do
                            if (type(rule[k]) ~= "table") then
                                if (m ~= 0) then
                                    if h[rule][i][j-1][k-1].bool and (rule[k] == str:sub(j-1, j-1)) then
                                        h[rule][i][j][k].bool = true
                                        h[rule][i][j][k].left = h[rule][i][j-1][k-1]
                                        h[rule][i][j][k].right = rule[k]
                                    end
                                end
                            else
                                for r = i, j do
                                    -- при r = i: a[rule[k]][r][j] вызывает недетерминированность, тк:
                                    -- 1) Может быть так, что rule[k] - это нетерминал, который еще не был
                                    --    в итерации цикла for nterm, ntermRules in pairs(rules). Тогда если
                                    --    a[nterm][i][j] должен был бы быть true, то это пока не так.
                                    -- 2) Может быть так, что rule[k] - это текущий нетерминал, по правилам 
                                    --    которого мы сейчас итерируемся. Тогда может быть так, что мы еще не
                                    --    дошли до того правила, которое сделает a[nterm][i][j] true.
                                    if h[rule][i][r][k-1].bool and a[rule[k][1]][r][j].bool then
                                        h[rule][i][j][k].bool = true
                                        h[rule][i][j][k].left = h[rule][i][r][k-1]
                                        h[rule][i][j][k].right = a[rule[k][1]][r][j]
                                        break
                                    end
                                end
                            end
                        end
                        if h[rule][i][j][#rule].bool then
                            a[nterm][i][j].bool = true
                            a[nterm][i][j].nterm = nterm
                            a[nterm][i][j].h = h[rule][i][j][#rule]
                        end
                    end
                end
                -- самый простой и тупой способ исправить недетерминированность выше - это продублировать
                --     проход в проблемных местах
                for nterm, ntermRules in pairs(rules) do
                    for _, rule in ipairs(ntermRules) do
                        for k = 1, #rule do
                            if not (type(rule[k]) ~= "table") then
                                local r = i
                                if h[rule][i][r][k-1].bool and a[rule[k][1]][r][j].bool then
                                    h[rule][i][j][k].bool = true
                                    h[rule][i][j][k].left = h[rule][i][r][k-1]
                                    h[rule][i][j][k].right = a[rule[k][1]][r][j]
                                    break
                                end
                            end
                        end
                        if h[rule][i][j][#rule].bool then
                            a[nterm][i][j].bool = true
                            a[nterm][i][j].nterm = nterm
                            a[nterm][i][j].h = h[rule][i][j][#rule]
                        end
                    end
                end
            end
        end
    end

    -- завершение:
    if a[startNterm][1][n+1].bool then
        return makeParseTree(a[startNterm][1][n+1])
    else
        return nil
    end
end