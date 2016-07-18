function [value] = GetTrigger(Port)
% GETTRIGGER(Port) reads the trigger status of a parallel port
%
% (optional) Port = hexadecimal version of port address (look it up in windows' device manager) 
%
% Rewritten on 30.03.2016 by Wanja Moessing

% use most common port address, if not supplied

global IO64PARALLELPORTOBJ;

if nargin<1
    Port = hex2dec('0378');
end

if isempty(IO64PARALLELPORTOBJ)
    OpenTriggerPort; % create interface object and open connection if OpenTrigger hasn't been used before
end

value = io64(IO64PARALLELPORTOBJ, Port);
end
