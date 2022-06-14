local Test = {
  last = nil,
  failed = nil,
  scope_info = nil,
}

function Test.fail(message)
  error(message or 'fail')
  return false
end

function Test.assert(pred, message)
  if not pred then
    return Test.fail(message)
  end
  return true
end

function Test.expect_fail(fn)
  assert(type(fn) == 'function')
  local ok, msg = pcall(fn)
  return Test.assert(not ok, msg)
end

function Test.info(info)
  Test.scope_info = Test.scope_info or {}
  table.insert(Test.scope_info, tostring(info))
end

function Test.reset()
  Test.scope_info = nil
end

function Test.run(tests)
  local ok, failed = 0, 0
  for k,v in pairs(tests) do
    Test.scope_info = nil
    if type(v) == 'function' then
      Test.failed = nil
      print("Running test "..k)

      local output = {}
      local oldprint = _G.print
      _G.print = function(str)
        table.insert(output, str)
      end
      local status, err = pcall(v)
      _G.print = oldprint
      if status and not Test.failed then
        ok = ok + 1
        print("[OK    ]")
      else
        failed = failed + 1
        print("[FAILED] "..(Test.failed or (err or "")))
        if Test.scope_info then
          if type(Test.scope_info) == 'string' then
            print("[  info] " .. Test.scope_info)
          elseif type(Test.scope_info) == 'table' then
            for _, line in ipairs(Test.scope_info) do
              print("[  info] " .. line)
            end
          end
        end
        for _, line in ipairs(output) do
          if type(line) == 'string' then
            print("> " .. line)
          end
        end
      end
    end
  end

  print("Ran "..(ok + failed).." tests ("..ok.." succeeded, "..failed.." failed)")
  if failed > 0 then
    os.exit(1)
  end
end

return Test
