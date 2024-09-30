-- Global variables for batching
if not _G.combined_logs then
    _G.combined_logs = {}
    _G.last_flush_time = os.time()
end

-- Flush interval in seconds (set to 2 seconds)
local FLUSH_INTERVAL = 2
-- Batch size (set to 10 records)
local BATCH_SIZE = 100000

function combine_logs_for_kusto(tag, timestamp, record)
    -- Add the current record's log to the combined logs
    table.insert(_G.combined_logs, record["log"])

    -- Get the current time
    local current_time = os.time()

    -- Check if it's time to flush (based on batch size or time interval)
    if #_G.combined_logs >= BATCH_SIZE or (current_time - _G.last_flush_time) >= FLUSH_INTERVAL then
        -- Combine logs into a single string with each entry separated by a newline
        local combined_log = table.concat(_G.combined_logs, "\n")

        -- Create the Kusto command with the combined log records
        local newRecord = {}
        newRecord["csl"] = string.format('.ingest inline into table application_logs with (format = "json", ingestionMappingReference = "json_mapping") <| \n %s', combined_log)
        newRecord["db"] = "NetDefaultDB"

        -- Reset the combined logs and update the last flush time
        _G.combined_logs = {}
        _G.last_flush_time = current_time

        -- Return the new combined record to Fluent Bit
        return 1, timestamp, newRecord
    else
        -- Do not emit any record yet; continue batching
        return -1, 0, nil
    end
end
