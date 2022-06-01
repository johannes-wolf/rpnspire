local Test = {
  last = nil,
  failed = nil
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

function Test.run(tests)
  local ok, failed = 0, 0
  for k,v in pairs(tests) do
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
        for _, v in ipairs(output) do
          if type(v) == 'string' then
            print("> "..(v or nil))
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
