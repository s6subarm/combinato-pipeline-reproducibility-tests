%% COMPARE_CELLWISE_MAT - Compare cell array contents between two .mat files.
%
%   Used for files like:
%       * cluster_info.mat
%
%   [ok, msg] = compare_cellwise_mat(newFile, oldFile)
%
%   INPUTS:
%       newFile - path to file produced by the NEW pipeline
%       oldFile - path to corresponding file from the OLD pipeline
%
%   OUTPUTS:
%       ok   - logical true if all cells match within tolerance
%       msg  - string describing mismatched entries or summary statistics
%
%   CHECKS PERFORMED:
%       1.  Presence of same variables (e.g., 'cluster_info')
%       2.  Same cell array size
%       3.  Element-wise comparison:
%               - numeric cells: |Δ| < 1e-6
%               - char/string cells: strcmp()
%       4.  Reports first few mismatches in 'msg'
%
%   NOTES:
%   - Handles cell arrays of mixed numeric and text content
%   - Empty cells are considered equal if both empty
%   - Comparison tolerance can be changed by editing 'tol'


function [ok, msg] = compare_cellwise_mat(newFile, oldFile)

    tol = 1e-6;
    ok  = true;
    msg = "";

    try
        A = load(newFile);
        B = load(oldFile);
    catch ME
        ok  = false;
        msg = sprintf('Failed to load: %s', ME.message);
        return;
    end

    % --- Find the main cell variable (cluster_info or similar)
    varCandidates = intersect(fieldnames(A), fieldnames(B));
    if isempty(varCandidates)
        ok = false;
        msg = 'No common variables found in .mat files.';
        return;
    end

    % Pick the first shared variable that is a cell
    cellVar = "";
    for v = 1:numel(varCandidates)
        name = varCandidates{v};
        if iscell(A.(name)) && iscell(B.(name))
            cellVar = name;
            break;
        end
    end
    if cellVar == ""
        ok = false;
        msg = 'No cell array variables found in either file.';
        return;
    end

    a = A.(cellVar);
    b = B.(cellVar);

    % --- Size check
    if ~isequal(size(a), size(b))
        ok  = false;
        msg = sprintf('Size mismatch in %s: [%s] vs [%s]', ...
            cellVar, num2str(size(a)), num2str(size(b)));
        return;
    end

    % --- Cell-by-cell comparison
    [nR, nC] = size(a);
    mismatches = {};
    for r = 1:nR
        for c = 1:nC
            x = a{r,c};
            y = b{r,c};
            if isnumeric(x) && isnumeric(y)
                if ~isequal(size(x), size(y))
                    ok = false;
                    mismatches{end+1} = sprintf('(%d,%d): size mismatch', r, c); %#ok<AGROW>
                else
                    d = max(abs(double(x(:)) - double(y(:))));
                    if d > tol
                        ok = false;
                        mismatches{end+1} = sprintf('(%d,%d): |Δ|=%.3g', r, c, d); %#ok<AGROW>
                    end
                end
            elseif ischar(x) && ischar(y)
                if ~strcmp(x, y)
                    ok = false;
                    mismatches{end+1} = sprintf('(%d,%d): text mismatch (%s ≠ %s)', r, c, x, y); %#ok<AGROW>
                end
            elseif isempty(x) && isempty(y)
                continue;
            else
                % different types
                ok = false;
                mismatches{end+1} = sprintf('(%d,%d): type mismatch (%s vs %s)', ...
                    r, c, class(x), class(y)); %#ok<AGROW>
            end
        end
    end

    % --- Format message
    if isempty(mismatches)
        msg = sprintf('%s: all %dx%d cells match within tolerance', cellVar, nR, nC);
    else
        n = numel(mismatches);
        previewN = min(5, n);
        msg = sprintf('%s: %d mismatches (showing %d): %s', ...
            cellVar, n, previewN, strjoin(mismatches(1:previewN), '; '));
    end

end
