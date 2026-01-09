%% COMPARE_CHECKSUM - Compare non-.mat files by size and SHA-256 hash.
%
%   Used for generic files such as:
%       * jobfile.txt, jobfile.json, logs
%       * images (.png, .jpg, .pdf, .eps)
%       * configuration or metadata files
%
%   [ok, msg] = compare_checksum(newFile, oldFile)
%
%   INPUTS:
%       newFile - path to file produced by the NEW pipeline
%       oldFile - path to corresponding file from the OLD pipeline
%
%   OUTPUTS:
%       ok   - logical true if files are byte-identical or have same SHA-256
%       msg  - string summarizing size and hash comparison
%
%   CHECKS PERFORMED:
%       1. File existence and size equality
%       2. SHA-256 checksum equality (if available)
%       3. Reports byte size difference and/or hash difference
%
%   NOTES:
%   - Works for text, image, and binary files.
%   - For very large files (>1 GB), checksum computation may be slower.
%   - If checksum cannot be computed (e.g., permission issue),
%     falls back to file size comparison only.


function [ok, msg] = compare_checksum(newFile, oldFile)

    ok  = true;
    msg = "";

    try
        infoNew = dir(newFile);
        infoOld = dir(oldFile);
    catch ME
        ok  = false;
        msg = sprintf('Failed to stat files: %s', ME.message);
        return;
    end

    if isempty(infoNew) || isempty(infoOld)
        ok  = false;
        msg = 'One or both files missing.';
        return;
    end

    % --- Compare sizes
    sizeDiff = abs(infoNew.bytes - infoOld.bytes);
    sameSize = (sizeDiff == 0);

    % --- Compute SHA-256 checksums
    try
        shaNew = getFileSHA256(newFile);
        shaOld = getFileSHA256(oldFile);
    catch ME
        warning('compare_checksum:hash', 'SHA-256 computation failed: %s', ME.message);
        shaNew = ''; shaOld = '';
    end

    % --- Decide outcome
    if ~isempty(shaNew) && ~isempty(shaOld)
        ok = strcmp(shaNew, shaOld);
        if ok
            msg = sprintf('SHA256 match (%s)', shaNew);
        else
            msg = sprintf('SHA256 differ: NEW=%s OLD=%s (Δbytes=%d)', ...
                shaNew, shaOld, sizeDiff);
        end
    else
        ok = sameSize;
        if ok
            msg = sprintf('Same file size (%d bytes), SHA-256 skipped', infoNew.bytes);
        else
            msg = sprintf('Size differ: NEW=%d OLD=%d (Δ=%d)', ...
                infoNew.bytes, infoOld.bytes, sizeDiff);
        end
    end
end


% ====== Local helper: SHA-256 checksum ======
function hash = getFileSHA256(fname)
    fid = fopen(fname, 'r');
    if fid == -1
        error('Cannot open file: %s', fname);
    end
    data = fread(fid, Inf, '*uint8');
    fclose(fid);

    % Use Java MessageDigest for SHA-256 hashing
    engine = java.security.MessageDigest.getInstance('SHA-256');
    engine.update(data);
    hash = sprintf('%02x', typecast(engine.digest(), 'uint8'));
end
