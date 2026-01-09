%% RUN_ALL_COMBINATO_TESTS - Compare outputs from NEW vs OLD Combinato pipelines for a single session.
%
%   USAGE (GUI):
%       >> run_all_combinato_tests
%
%   USAGE (explicit paths):
%       >> run_all_combinato_tests('/path/to/new/session', '/path/to/old/session')
%
%   OUTPUT:
%       resultsTable  - MATLAB table with per-file comparison results
%
%   NOTES:
%   - Dispatches comparisons by file type / extension:
%
%           * times_CSC*.mat, CSC*_spikes.mat, * channels.mat,    --> compare_elementwise_mat
%           * cluster_info.mat                                    --> compare_cellwise_mat
%           * qMetrics.mat (or *_qMetrics.mat), reflookup.mat     --> compare_struct_metrics
%           * ChannelNames.txt, do_sort_pos.txt                   --> compare_text_exact
%           * Any .csv file                                       --> compare_structured_csv
%           * .h5/.png/.jpg/.tif/.eps/.fig                        --> size-only comparison
%           * .log/.json/.yaml/.pdf/.txt                          --> skipped (non-deterministic)
%
%   - Writes CSV report under test_codes/logs/
%   - Skips folders named combinatostuff_*
%   - Includes metadata: timestamp, MATLAB version, hostname

function resultsTable = run_all_combinato_tests(newDir, oldDir)
% ============================================================
% 1️⃣ Folder Setup and File Discovery
% ============================================================
    if nargin < 1 || ~isfolder(newDir)
        newDir = pickDir('Select NEW pipeline output folder');
        if ~isfolder(newDir), fprintf('Cancelled.\n'); return; end
    end
    if nargin < 2 || ~isfolder(oldDir)
        oldDir = pickDir('Select OLD pipeline output folder');
        if ~isfolder(oldDir), fprintf('Cancelled.\n'); return; end
    end

    fprintf('\nComparing session folders:\n  NEW: %s\n  OLD: %s\n\n', newDir, oldDir);

    % Recursively collect files, excluding folders starting with combinatostuff_
    newFiles = dir(fullfile(newDir, '**', '*.*'));
    oldFiles = dir(fullfile(oldDir, '**', '*.*'));
    newFiles = newFiles(~[newFiles.isdir]);
    oldFiles = oldFiles(~[oldFiles.isdir]);
    excludePattern = 'combinatostuff_';
    newFiles = newFiles(~contains({newFiles.folder}, excludePattern));
    oldFiles = oldFiles(~contains({oldFiles.folder}, excludePattern));

    % Build relative path maps
    relNew = arrayfun(@(d) erase(fullfile(d.folder, d.name), [newDir filesep]), newFiles, 'uni', 0);
    relOld = arrayfun(@(d) erase(fullfile(d.folder, d.name), [oldDir filesep]), oldFiles, 'uni', 0);
    newMap = containers.Map(relNew, 1:numel(relNew));
    oldMap = containers.Map(relOld, 1:numel(relOld));
    allKeys = unique([relNew(:); relOld(:)]);

% ============================================================
% 2️⃣ Helper Availability
% ============================================================
    have.elem       = exist('compare_elementwise_mat', 'file') == 2;
    have.cell       = exist('compare_cellwise_mat',    'file') == 2;
    have.struct     = exist('compare_struct_metrics',  'file') == 2;
    have.sum        = exist('compare_checksum',        'file') == 2;
    have.txt        = exist('compare_text_exact',      'file') == 2;
    have.csvstruct  = exist('compare_structured_csv',  'file') == 2;

% ============================================================
% 3️⃣ Main Comparison Dispatch
% ============================================================
    rows = [];
    for k = 1:numel(allKeys)
        relPath = allKeys{k};
        [~, name, ext] = fileparts(relPath);
        ext = lower(ext);
        pNew = fullfile(newDir, relPath);
        pOld = fullfile(oldDir, relPath);

        entry = initEntry(relPath, ext);

        % --- Presence checks ---
        inNew = isKey(newMap, relPath);
        inOld = isKey(oldMap, relPath);
        if ~inNew && ~inOld
            entry = skip(entry, 'Missing in both (unexpected)'); rows = [rows; entry]; continue;
        elseif inNew && ~inOld
            entry = fail(entry, 'Missing in OLD'); rows = [rows; entry]; continue;
        elseif ~inNew && inOld
            entry = fail(entry, 'Missing in NEW'); rows = [rows; entry]; continue;
        end

        % ============================================================
        % Dispatch by file extension
        % ============================================================

        % 1️⃣ Deterministic text (.txt)
        if strcmp(ext, '.txt')
            if any(strcmpi(name, {'ChannelNames','do_sort_pos'}))
                if have.txt
                    [ok, msg] = compare_text_exact(pNew, pOld);
                    [entry.result, entry.detail] = toResult(ok, msg);
                    entry.check = 'text-exact';
                else
                    entry = skip(entry, 'Helper compare_text_exact.m missing');
                end
            else
                entry = skip(entry, 'Skipped (non-deterministic text)');
            end
            rows = [rows; entry]; continue;
        end

        % 2️⃣ Structured CSVs
        if strcmp(ext, '.csv')
            if have.csvstruct
                [ok, msg] = compare_structured_csv(pNew, pOld);
                [entry.result, entry.detail] = toResult(ok, msg);
                entry.check = 'csv-structured';
            else
                entry = skip(entry, 'Helper compare_structured_csv.m missing');
            end
            rows = [rows; entry]; continue;
        end

        % 3️⃣ MAT files
        if strcmp(ext, '.mat')
            entry = handleMatFile(entry, have, pNew, pOld);
            rows = [rows; entry]; continue;
        end

        % 4️⃣ Images / HDF / EPS / FIG (size-only)
        if any(strcmp(ext, {'.h5','.png','.jpg','.jpeg','.tif','.tiff','.eps','.fig'}))
            entry = sizeOnlyCompare(entry, pNew, pOld);
            rows = [rows; entry]; continue;
        end

        % 5️⃣ Non-deterministic configs
        if any(strcmp(ext, {'.log','.json','.yaml','.yml','.pdf'}))
            entry = skip(entry, 'Skipped (non-deterministic log/config/pdf)');
            rows = [rows; entry]; continue;
        end

        % 6️⃣ Everything else → checksum
        if have.sum
            [ok, msg] = compare_checksum(pNew, pOld);
            [entry.result, entry.detail] = toResult(ok, msg);
            entry.check = 'checksum';
        else
            entry = skip(entry, 'Helper compare_checksum.m missing');
        end
        rows = [rows; entry];
    end

% ============================================================
% 4️⃣ Results Table + CSV Logging
% ============================================================
    resultsTable = struct2table(rows);
    resultsTable = movevars(resultsTable, ...
        {'file_rel','file_type','check','result','detail','size_diff_bytes'}, 'Before', 1);
    [~, ix] = sort(lower(resultsTable.file_rel));
    resultsTable = resultsTable(ix, :);
    printSummary(resultsTable);

    logDir = fullfile(fileparts(mfilename('fullpath')), 'logs');
    if ~exist(logDir, 'dir'), mkdir(logDir); end
    ts = datestr(now, 'yyyymmdd_HHMMSS');
    outCsv = fullfile(logDir, sprintf('comparison_results_%s.csv', ts));

    fid = fopen(outCsv, 'w');
    fprintf(fid, '%% COMBINATO TEST LOG\n');
    fprintf(fid, '%% Timestamp: %s\n', ts);
    fprintf(fid, '%% MATLAB Version: %s\n', version);
    [~, host] = system('hostname');
    fprintf(fid, '%% Hostname: %s\n', strtrim(host));
    fprintf(fid, '%% NewDir: %s\n', newDir);
    fprintf(fid, '%% OldDir: %s\n', oldDir);
    fprintf(fid, '%% -------------------------------------------------------------------------------------------------\n');
    fclose(fid);
    writetable(resultsTable, outCsv, 'WriteMode', 'Append');
    fprintf('\nReport written: %s\n', outCsv);
end

% ============================================================
% Helper Subfunctions
% ============================================================

function e = initEntry(relPath, ext)
    e.file_rel = relPath;
    e.file_type = detectType(relPath);
    e.check = '';
    e.result = 'SKIP';
    e.detail = '';
    e.size_diff_bytes = NaN;
end

function e = skip(e, reason)
    e.result = 'SKIP';
    e.detail = reason;
end

function e = fail(e, reason)
    e.result = 'FAIL';
    e.detail = reason;
end

function e = sizeOnlyCompare(e, pNew, pOld)
    infoNew = dir(pNew);
    infoOld = dir(pOld);
    if isempty(infoNew) || isempty(infoOld)
        e.result = 'FAIL';
        e.detail = 'Missing file(s)';
        return;
    end
    sizeDiff = abs(infoNew.bytes - infoOld.bytes);
    e.size_diff_bytes = sizeDiff;
    if sizeDiff == 0
        e.result = 'PASS';
        e.detail = sprintf('Same file size (%d bytes)', infoNew.bytes);
    else
        e.result = 'WARN';
        e.detail = sprintf('File size differ: NEW=%d OLD=%d (Δ=%d)', ...
            infoNew.bytes, infoOld.bytes, sizeDiff);
    end
end

function e = handleMatFile(e, have, pNew, pOld)
    switch e.file_type
        case {'mat_times','mat_spikes','mat_numeric_generic'}
            helper = 'compare_elementwise_mat';
            fn = @compare_elementwise_mat;

        case 'mat_clusterinfo'
            helper = 'compare_cellwise_mat';
            fn = @compare_cellwise_mat;

        case {'mat_qmetrics','mat_struct_generic'}
            helper = 'compare_struct_metrics';
            fn = @compare_struct_metrics;

        otherwise
            helper = 'compare_checksum';
            fn = @compare_checksum;
    end

    if exist(helper, 'file') == 2
        [ok, msg] = fn(pNew, pOld);
        [e.result, e.detail] = toResult(ok, msg);
        e.check = strrep(helper, 'compare_', '');
    else
        e = skip(e, sprintf('Helper %s.m missing', helper));
    end
end

function [res, detail] = toResult(ok, msg)
    if ok
        res = 'PASS';
    else
        res = 'FAIL';
    end
    if nargin < 2 || isempty(msg), detail = ''; else, detail = msg; end
end

function p = pickDir(prompt)
    try
        p = uigetdir(pwd, prompt);
        if isequal(p, 0), p = ""; end
    catch
        fprintf('%s\n', prompt);
        p = strtrim(input('Enter folder path: ', 's'));
    end
end

function t = detectType(relPath)
    [~, name, ext] = fileparts(relPath);
    lowerName = lower(name);
    ext = lower(ext);
    if strcmp(ext, '.mat')
        if startsWith(lowerName, 'times_csc')
            t = 'mat_times';
        elseif ~isempty(regexp(lowerName, '^csc\d+_spikes$', 'once'))
            t = 'mat_spikes';
        elseif strcmpi([name ext], 'cluster_info.mat')
            t = 'mat_clusterinfo';
        elseif contains(lowerName, 'qmetrics')
            t = 'mat_qmetrics';

        elseif strcmpi(lowerName, 'channels')
            t = 'mat_numeric_generic';

        elseif strcmpi(lowerName, 'reflookup')
            t = 'mat_struct_generic';

        else
            t = 'mat_other';
        end
    else
        t = ['generic' ext];
    end
end

function printSummary(T)
    passN = sum(strcmpi(T.result,'PASS'));
    failN = sum(strcmpi(T.result,'FAIL'));
    skipN = sum(strcmpi(T.result,'SKIP'));
    warnN = sum(strcmpi(T.result,'WARN'));
    errN  = sum(strcmpi(T.result,'ERROR'));
    fprintf('-------------------------------------------------------------\n');
    fprintf('%-40s | %-9s | %-10s | %-6s\n', 'File', 'Type', 'Check', 'Result');
    fprintf('-------------------------------------------------------------\n');
    for i = 1:height(T)
        fileDisp = T.file_rel{i};
        if strlength(fileDisp) > 40
            fileDisp = ['...' char(extractAfter(fileDisp, strlength(fileDisp)-36))];
        end
        fprintf('%-40s | %-9s | %-10s | %-6s\n', ...
            fileDisp, T.file_type{i}, T.check{i}, T.result{i});
    end
    fprintf('-------------------------------------------------------------\n');
    fprintf('Summary: %d PASS, %d FAIL, %d WARN, %d SKIP, %d ERROR (Total: %d)\n', ...
        passN, failN, warnN, skipN, errN, height(T));
end
