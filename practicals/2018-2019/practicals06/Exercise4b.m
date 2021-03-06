%-------------------------------------------------------------------------%
%        ___  ___      _   _       _       ___ _____ ______ _____         |
%        |  \/  |     | | | |     | |     /   /  __ \| ___ \  ___|        |
%        | .  . | __ _| |_| | __ _| |__  / /| | /  \/| |_/ / |__          |
%        | |\/| |/ _` | __| |/ _` | '_ \/ /_| | |    |    /|  __|         |
%        | |  | | (_| | |_| | (_| | |_) \___  | \__/\| |\ \| |___         |
%        \_|  |_/\__,_|\__|_|\__,_|_.__/    |_/\____/\_| \_\____/         |
%                                                                         |
%                                                                         |
%   Author: Alberto Cuoci <alberto.cuoci@polimi.it>                       |
%   CRECK Modeling Group <http://creckmodeling.chem.polimi.it>            |
%   Department of Chemistry, Materials and Chemical Engineering           |
%   Politecnico di Milano                                                 |
%   P.zza Leonardo da Vinci 32, 20133 Milano                              |
%                                                                         |
%-------------------------------------------------------------------------|
%                                                                         |
%   This file is part of Matlab4CRE framework.                            |
%                                                                         |
%	License                                                               |
%                                                                         |
%   Copyright(C) 2017 Alberto Cuoci                                       |
%   Matlab4CRE is free software: you can redistribute it and/or modify    |
%   it under the terms of the GNU General Public License as published by  |
%   the Free Software Foundation, either version 3 of the License, or     |
%   (at your option) any later version.                                   |
%                                                                         |
%   Matlab4CRE is distributed in the hope that it will be useful,         |
%   but WITHOUT ANY WARRANTY; without even the implied warranty of        |
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         |
%   GNU General Public License for more details.                          |
%                                                                         |
%   You should have received a copy of the GNU General Public License     |
%   along with Matlab4CRE. If not, see <http://www.gnu.org/licenses/>.    |
%                                                                         |
%-------------------------------------------------------------------------%
%                                                                         %
% Examples of 1 parameter models                                          %
% The RTD is fitted using 4 Gaussian functions                            %
% Dispersion model (only estimation of dispersion coefficient)            %
% Tanks in Series model                                                   %
% Requires at least MATLAB-2016b                                          %
%                                                                         %
%-------------------------------------------------------------------------%

close all;
clear all;

global psi;
global m0;

% Experimental data
N = 21;
t = [0 1 2 2.2 2.4 2.6 2.8 3 3.2 3.4 3.6 3.8 4 4.2 4.4 4.6 4.8 5 6 7 8]';
E = [0 0 0 0.010640797 0.042563186 0.085126373 0.127689559 0.255379118 ...
     0.681010982 0.851263728 0.851263728 0.766137355 0.427055382 ...
     0.284703588 0.170252746 0.127689559 0.085126373 0.042563186 ...
     0.021281593 0	0 ];

% User data
k = 0.1;        % kinetic constant [m3/kmol/s]
L = 30;         % reactor length [m]
D = 0.04;       % reactor diameter [m]
v = 8.1;        % velocity [m/s]
CAin = 10;      % inlet concentration [kmol/m3]

% Preliminary calculations
A = pi*D^2/4;   % cross section area [m2]
Q = v*A;        % volumetric flow rate [m3/s]
V = A*L;        % volume [m3]

% Ideal PFR
tau = V/Q;
CApfr = CAin/(1+k*tau*CAin);

% ------------------------------------------------------------------------%
% Fitting of E using non-linear regression analysis                       %
% E is modeled as a weighted sum of 4 Gaussian functions                  %
%-------------------------------------------------------------------------%

firstGuess = [0.8 3.5 0.5  0.8 3.5 0.5 0.1 6 0.2 0.1 6 0.2 ];
nlm = fitnlm(t,E,@Eanalytical,firstGuess);
for i=1:nlm.NumCoefficients
    psi(i)  = nlm.Coefficients.Estimate(i);
end
plot(t, Eanalytical(psi,t), t,E);


% ------------------------------------------------------------------------%
% Analysis of RTD                                                         %
% ------------------------------------------------------------------------%

% Normalization of E (to be sure that the area below is 1)
m0 = integral(@one_times_Eanalytical, 0., t(end));

% Mean residence time: tm = int(t*E*dt)
tm = integral(@t_times_Eanalytical, 0., t(end));

% Variance: sigma2 = m2 - int(t2*E*dt)
m2 = integral(@t2_times_Eanalytical, 0., t(end));
sigma2 = m2-tm^2;
sigmaTeta2 = sigma2/tm^2;

fprintf('From RTD: tm=%f [s] - sigma2=%f [s2] - sigmaTeta2=%f \n', ...
         tm, sigma2, sigmaTeta2);

% ------------------------------------------------------------------------%
% Dispersion model: dispersion coefficient
% ------------------------------------------------------------------------%
Pe = 2/sigmaTeta2;
for i=1:10
    Pe = 2/sigmaTeta2*(1-1/Pe*(1-exp(-Pe)));
end
GammaEff = L*v/Pe;                             % [m2/s]

fprintf('DM: Pe=%f - GammaEff=%f [m2/s]\n', Pe, GammaEff);


% ------------------------------------------------------------------------%
% Tanks in Series model
% ------------------------------------------------------------------------%
n = 1/sigmaTeta2;   % non-integer number

% Plus
n_plus  = ceil(n);
tau_plus = tm/n_plus;
CA(1) = CAin;
for i=2:n_plus+1
    CA(i) = (-1+sqrt(1+4*k*tau_plus*CA(i-1)))/(2*k*tau_plus);
end
CA_plus = CA(end);

% Minus
n_minus = floor(n);
tau_minus = tm/n_minus;
CA(1) = CAin;
for i=2:n_minus+1
    CA(i) = (-1+sqrt(1+4*k*tau_minus*CA(i-1)))/(2*k*tau_minus);
end
CA_minus = CA(end);

%Interpolation
CA_tis = CA_minus + (CA_plus-CA_minus)/(n_plus-n_minus)*(n-n_minus);

%Print on the screen
fprintf('A) TIS: %f - PFR: %f [kmol/m3]\n', CA_tis(end), CApfr);
fprintf('X) TIS: %f - PFR: %f [kmol/m3]\n', 1-CA_tis/CAin, 1-CApfr/CAin);


% ------------------------------------------------------------------------%
% Analytical RTD
% ------------------------------------------------------------------------%

function F = Eanalytical(a,t)

    F = a(1)*exp(-(t-a(2)).^2/a(3))+ ...
        a(4)*exp(-(t-a(5)).^2/a(6))+ ...
        a(7)*exp(-(t-a(8)).^2/a(9))+ ...
        a(10)*exp(-(t-a(11)).^2/a(12));

end

function F = one_times_Eanalytical(t)

    global psi;
    F = Eanalytical(psi,t);

end

function F = t_times_Eanalytical(t)

    global psi;
    global m0;
    F = m0*t.*Eanalytical(psi,t);

end

function F = t2_times_Eanalytical(t)

    global psi;
    global m0;
    F = m0*t.^2.*Eanalytical(psi,t);

end