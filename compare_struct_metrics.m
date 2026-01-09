%% COMPARE_STRUCT_METRICS - Field-wise comparison of struct-based metric files.
%
%   Used for files like:
%       * qMetrics.mat
%
%   [ok, msg] = compare_struct_metrics(newFile, oldFile)
%
%   INPUTS:
%       newFile - path to file produced by the NEW pipeline
%       oldFile - path to corresponding file from the OLD pipeline
%
%   OUTPUTS:
%       ok   - logical true if all matching struct fields pass within tolerance
%       msg  - string summarizing differences per field
%
%   CHECKS PERFORMED:
%       1.  Identical field names in both structs
%       2.  Equal sizes of each corresponding field
%       3.  Element-wise difference within tolerance (default 1e-6)
%       4.  Reports maximum absolute difference per field
%
%   NOTES:
%   - Non-numeric fields are skipped (listed in msg)
%   - Structs can be nested; subfields are compared recursively
%   - Tolerance can be tuned via 'tol'


function [ok, msg] = compare_struct_metrics(newFile, oldFile)

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

    % --- Detect main struct variable
    commonVars = intersect(fieldnames(A), fieldnames(B));
    if isempty(commonVars)
        ok = false;
        msg = 'No common variables found.';
        return;
    end

    structVar = "";
    for i = 1:numel(commonVars)
        n = commonVars{i};
        if isstruct(A.(n)) && isstruct(B.(n))
            structVar = n;
            break;
        end
    end
    if structVar == ""
        ok = false;
        msg = 'No struct variables found in either file.';
        return;
    end

    % --- Compare structs recursively
    diffs = compareStructRecursive(A.(structVar), B.(structVar), tol);
    ok = diffs.ok;
    msg = diffs.msg;

end


% ====== Local recursive comparison helper ======
function out = compareStructRecursive(a, b, tol, prefix)
    if nargin < 4, prefix = ''; end

    out.ok  = true;
    out.msg = "";

    if ~isstruct(a) || ~isstruct(b)
        out.ok = false;
        out.msg = sprintf('%s: one of inputs not a struct', prefix);
        return;
    end

    fieldsA = fieldnames(a);
    fieldsB = fieldnames(b);

    % Field name mismatch
    if ~isequal(sort(fieldsA), sort(fieldsB))
        out.ok = false;
        out.msg = sprintf('%s: field mismatch (NEW: %s | OLD: %s)', ...
            prefix, strjoin(fieldsA, ','), strjoin(fieldsB, ','));
        return;
    end

    lines = {};
    for f = 1:numel(fieldsA)
        name = fieldsA{f};
        fullName = strcat(prefix, '.', name);
        va = a.(name);
        vb = b.(name);

        if isstruct(va) && isstruct(vb)
            sub = compareStructRecursive(va, vb, tol, fullName);
            if ~sub.ok
                out.ok = false;
            end
            if ~isempty(sub.msg)
                lines{end+1} = sub.msg; %#ok<AGROW>
            end

        elseif isnumeric(va) && isnumeric(vb)
            if ~isequal(size(va), size(vb))
                out.ok = false;
                lines{end+1} = sprintf('%s: size mismatch [%s] vs [%s]', ...
                    fullName, num2str(size(va)), num2str(size(vb))); %#ok<AGROW>
            else
                d = abs(double(va(:)) - double(vb(:)));
                maxD = max(d);
                lines{end+1} = sprintf('%s: max |Δ| = %.3g', fullName, maxD); %#ok<AGROW>
                if maxD > tol
                    out.ok = false;
                end
            end
        else
            lines{end+1} = sprintf('%s: skipped (non-numeric or type mismatch: %s vs %s)', ...
                fullName, class(va), class(vb)); %#ok<AGROW>
        end
    end

    out.msg = strjoin(lines, '; ');
end
