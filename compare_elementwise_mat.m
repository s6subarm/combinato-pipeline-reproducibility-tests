%% COMPARE_ELEMENTWISE_MAT - Element-wise comparison of numeric .mat files.
%
%   Used for files like:
%       * times_CSC*.mat
%       * CSC*_spikes.mat
%
%   [ok, msg] = compare_elementwise_mat(newFile, oldFile)
%
%   INPUTS:
%       newFile - path to file produced by the NEW pipeline
%       oldFile - path to corresponding file from the OLD pipeline
%
%   OUTPUTS:
%       ok   - logical true if all comparisons pass within tolerance
%       msg  - string describing the comparison result
%
%   CHECKS PERFORMED:
%       1.  Same variables present in both files
%       2.  Equal matrix sizes for matching variables
%       3.  Element-wise numeric difference within tolerance (default 1e-6)
%       4.  Reports max absolute difference per variable
%
%   NOTES:
%   - Non-numeric or mismatched variable types are ignored (reported)
%   - Tolerances may be adapted in future by adding a "tol" argument


function [ok, msg] = compare_elementwise_mat(newFile, oldFile)

    tol = 1e-6;  % numeric tolerance
    ok  = true;
    msg = "";

    % Load both files
    try
        A = load(newFile);
        B = load(oldFile);
    catch ME
        ok  = false;
        msg = sprintf('Failed to load: %s', ME.message);
        return;
    end

    varsA = fieldnames(A);
    varsB = fieldnames(B);

    % --- Variable list match
    if ~isequal(sort(varsA), sort(varsB))
        ok  = false;
        msg = sprintf('Variable mismatch:\n  NEW: %s\n  OLD: %s', ...
            strjoin(varsA, ', '), strjoin(varsB, ', '));
        return;
    end

    % --- Compare each variable
    diffs = struct();
    for v = 1:numel(varsA)
        name = varsA{v};
        a = A.(name);
        b = B.(name);

        if isnumeric(a) && isnumeric(b)
            if ~isequal(size(a), size(b))
                ok = false;
                diffs.(name) = sprintf('Size mismatch: [%s] vs [%s]', ...
                    num2str(size(a)), num2str(size(b)));
                continue;
            end
            delta = abs(double(a) - double(b));
            maxDiff = max(delta(:));
            diffs.(name) = sprintf('max |Δ| = %.3g', maxDiff);
            if maxDiff > tol
                ok = false;
            end
        else
            % Non-numeric variable
            diffs.(name) = 'Skipped (non-numeric)';
        end
    end

    % --- Format message
    names = fieldnames(diffs);
    lines = cellfun(@(n) sprintf('%s: %s', n, diffs.(n)), names, 'uni', 0);
    msg = strjoin(lines, '; ');

end
