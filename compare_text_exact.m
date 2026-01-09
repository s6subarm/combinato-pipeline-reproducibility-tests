%% COMPARE_TEXT_EXACT - Line-by-line comparison for small deterministic text files.
%
%   Used for:
%       * ChannelNames.txt
%       * do_sort_pos.txt
%
%   [ok, msg] = compare_text_exact(newFile, oldFile)
%
%   Returns:
%       ok  - true if identical
%       msg - description of mismatch (if any)
%
%   Notes:
%   - Compares the two text files line-by-line (ignores leading/trailing spaces).
%   - Reports the first mismatch or confirms identical content.

function [ok, msg] = compare_text_exact(newFile, oldFile)
    try
        % Read text safely (returns string array)
        newLines = strtrim(string(readlines(newFile)));
        oldLines = strtrim(string(readlines(oldFile)));

        % Check line count
        if numel(newLines) ~= numel(oldLines)
            ok = false;
            msg = sprintf('Different number of lines: NEW=%d OLD=%d', ...
                          numel(newLines), numel(oldLines));
            return;
        end

        % Find differing lines
        diffIdx = find(~strcmp(newLines, oldLines));
        if isempty(diffIdx)
            ok = true;
            msg = sprintf('Identical (%d lines)', numel(newLines));
        else
            ok = false;
            msg = sprintf('Mismatch at line %d: NEW="%s" | OLD="%s"', ...
                          diffIdx(1), newLines(diffIdx(1)), oldLines(diffIdx(1)));
        end
    catch ME
        ok = false;
        msg = sprintf('Error comparing text files: %s', ME.message);
    end
end
