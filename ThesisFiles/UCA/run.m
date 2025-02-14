%% UCA Uncoordinated Charging Algorithm 
% Charge as soon as arrives in station
% Issue High charging cost 

clc
clear
close all

% Load data
tic

evNum = 200;
dataName = strcat('ev', num2str(evNum), '.xls');
printName = strcat('power_uca_ev_',num2str(evNum), '.png');
data = readmatrix(dataName);

% Transformer maximum power 
% ev = 200, tp  = 833;
tp  = 833;

% Time slot in minutes
minute = 5;
fmax = 8;


% Initial SOC
soci = data(:, 3);

% Final/Desired SOC
socf = data(:, 4);

% Number of EV
ev = length(soci);

% Total Cost
TOTAL_COST = 0;

% Record each EV historical power and charging cost
final(ev) = struct();


% Maximum charging power for each EV(kW)
pmax = 7;

% Each EV Battery capacity(kWh)
cap = 44;

% Time slot in integer 
tslot = minute/60;

% Simulation Horizon 1 day --> 24 Hours
ending = 24./tslot;
starting = 1;

% Initial Power limits
lb = zeros(1, ending);
ub = zeros(1, ending);

% Transform arrival time from hours to number of time slots
arival = data(:, 1)./tslot;

% First EV to get into the station 
min_arr = min(arival);

% Transform departure time from hours to number of time slots
departure = data(:, 2)./tslot;

% Last EV to leave  the station 
max_dep = max(departure);

% Transfomer remaining maximum power after charging each EV
trans = tp.*ones(1, ending);

% For ploting 
ptmax = 60;
plot_trans = trans;
plot_trans(1:min_arr -1) = ptmax;
plot_trans(max_dep +1:end) = ptmax;

% No inequalities constraint 
A = [];
b = [];

% TOU
low = 1.69/30;
high = 3.62/30;


% Low pricing periods
low_time = 8/tslot;

% High pricing periods
high_time = 9/tslot; 

% Low pricing periods
last_time = 7/tslot;

TOTAL_POWER = zeros(starting, ending).';

% First come first serve 
[~, index ]  = sort(arival);


M = normal_price(low, high, low_time, high_time, last_time);
writematrix(M.','TOU.xls');

satisfied = 0;
% Uncomment 
for i = 1: ev
    
    % Pricing pattern to allow charging as soon as arrive in sation
    % un for uncoordinated 
    f = un_price(low_time + high_time + last_time);
    
    % Reference charging pattern price for cost
    f_normal = normal_price(low, high, low_time, high_time, last_time);
    Aeq = ones(1, ending);
    
    % SOC needed 
    beq = (socf(index(i)) - soci(index(i))).*cap./tslot;
    
    % Update maximum charging power due to transformer constraint
    [~, indexmax] = find (trans >= pmax);
    [~, indexnorm] = find (trans < pmax);
    
    % No overload 
    ub(indexmax) = pmax;
    
    % Overload
    ub(indexnorm) = trans(indexnorm);
    
    % Used to evaluate real cost
    section = arival(index(i)):departure(index(i));
    Aeq_c = Aeq(section);
    lb_c = lb(section);
    ub_c = ub(section);
    price = f_normal(section);
    
    
    
    % No charging before arrival and after departure
    ub(starting:arival(index(i))-1) = 0;
    ub(departure(index(i)) + 1:end) = 0;
    
    % Time in station 
    duration = departure(index(i)) - arival(index(i));
    
    % Total power if pamx was given 
    possible = sum(ub);
    
    % short stay, desired SOC is changed 
    ispos = possible - beq;
    if ispos < 0 
        beq = possible;
        
    else
        satisfied = satisfied + 1;
    end
    
    
    % SOC at departure time
    socfinal = beq.*tslot/cap + soci(index(i));
    
 
    % No charging before arrival and after departure
    f(starting:arival(index(i))-1) = fmax; % Fill with red color 
    f(departure(index(i)) + 1:end) = fmax; % Fill with red color 
    
    % Evalute charging cost using energy
    energy = tslot.*price;
    [ch, cost] = linprog(energy,A,b,Aeq_c,beq,lb_c,ub_c);
    
    % Total station charging cost 
    TOTAL_COST = TOTAL_COST + cost;
    
    % Evalute charging power 
    [pow, fval] = linprog(f.*tslot,A,b,Aeq,beq,lb,ub);
    check_pow = isequal(sum(ch), sum(pow));
    TOTAL_POWER = TOTAL_POWER + pow;
    
    % record each EV power and charging cost 
    final(index(i)).power = pow;
    
    final(index(i)).cost = cost;
    
    % Residual Transformer power after charging EV i
    trans = trans - pow.';
    
% % Plot EV power
%     figure(index(i)) 
%     subplot(3, 1, 1)
%     
%    plot_price(f, fmax)
% 
%     subplot(3, 1, 2)
%     bar(pow, 'y')
%     title('Power(kW)')
%     set(gca,'FontSize',20);
%     subplot(3, 1, 3)
%     
%     plot_soc(soci(index(i)), -pow, cap, tslot)
%     
%     
%     %disp(['Figure ' num2str(i)])
%     title(['Initial SOC: ', num2str(100.*soci(index(i))), ...
%         '         Desired SOC : ', num2str(100.*socf(index(i))),...
%         '         Final SOC : ', num2str(100.*socfinal)], 'color', 'w')
        
  
    f = [];
    f_normal = [];
end
toc
% Plot transformer power vs total consumed power
% f1 = figure(100);

% % trans_limit(plot_trans, TOTAL_POWER, ptmax)
% % Actual plot 
% plot_pow(-TOTAL_POWER, -tp);
% C = [final(:).cost];
% %writematrix(C,'g2vresult300_800.xls')
% 
% %TOTAL_COST
% price = normal_price(low, high, low_time, high_time, last_time);
% price = price.';
% 
% tslot = 5/60;
% 
% pp = tslot.*price.*TOTAL_POWER;
% % Total Charging cost
% % satisfied 
%  cost = sum(pp(:))

TOTAL_COST
% plot_pow(-TOTAL_POWER, -tp);
 plot_pv_conf(-TOTAL_POWER, tp, printName)

