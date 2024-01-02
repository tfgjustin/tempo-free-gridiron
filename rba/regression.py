#!/usr/bin/python
#
# regression.py - describes a linear regression analysis
#
# This file is used to perform least-squares estimation for a given variable.
# Each point is assumed to be an (x,y)-pair.  This function will compute the
# least-squares fit to y = m*x + b for those two values.  It does not attempt
# to interpret the results.  If you want that, you need to subclass this class.
#
# Author:  epettis@google.com (Eddie Pettis)

import constants
import math
import numpy as np
from scipy import interpolate

class Sample (object):
    def __init__(self, t, x, y):
        if math.isnan(t) or math.isnan(x) or math.isnan(y):
            print "(t, x, y) = (%f, %f, %f)" % (t, x, y)
            raise FloatingPointException

        self._t = t
        self._x = x
        self._y = y
    def __cmp__(self, other):
        return cmp(self._x, other.x())
    def __str__(self):
        return "(t, x, y) = (%.3f, %.3f, %.3f)" % (self._t, self._x, self._y)
    def t(self):
        return self._t
    def x(self):
        return self._x
    def y(self):
        return self._y

class Regression (object):
    """Describes linear regression of an (x,y)-pair."""
    def __init__(self):
        self._samples = []
        self._slope = 0
        self._intercept = 0
        self._max_week = -1
        self._tck = None

    def intercept(self):
        return self._intercept

    def mean(self):
        """Computes mean of y-values"""
        y_values = [a.y() for a in self._samples]
        if len(y_values) > 0:
            return sum(y_values) / (len(y_values)*1.0)
        else:
            return 0

    def samples(self):
        return self._samples

    def slope(self):
        return self._slope

    def variance(self):
        """Computes variance of y-values."""
        mean = self.mean()
        this_sum = 0
        y_values = [a.y() for a in self._samples]
        if len(self._samples) < 1:
            return 0
        for s in y_values:
            this_sum += (s - mean)**2
        variance = this_sum / (len(self._samples)*1.0)
        return variance

    def Append(self, new_sample):
        """All samples must be (t,x,y)-tuples."""
        sample_object = Sample(new_sample[0], new_sample[1], new_sample[2])
        self._samples.append(sample_object)
        week = sample_object.t()
        if week > self._max_week:
            self._max_week = week

    def Compute(self, x, nslope=0, pslope=0):
        # If we require positive slope (pslope) or negative slope (nslope),
        # we just catch it here.
        if ((pslope != 0 and self._slope < 0) or \
            (nslope != 0 and self._slope > 0)):
            return self._intercept

        # If we've never updated this before, we still need to come up with a
        # value.  If we've never seen it, we assume it's zero.  If we don't
        # have enough points to interpolate, we use the average.  Once we've
        # seen enough points to interpolate, we do the math using the
        # weighted least squares curve.
        if not self._tck:
            N = len(self._samples)
            if N == 0:
                return 0
            else:
                y = [float(a.y()) for a in self._samples]
                average = 0
                for i in y:
                    average += i
                average /= N
                return average
        else:
            return interpolate.splev(x, self._tck, der=0)
 
    def Extend(self, many_samples):
        for sample in many_samples:
            self.Append(sample)

    def Join(self, other_regression):
        self._samples.extend(other_regression.samples())

    def Update(self):
        """
        Updates slope and intercept values.

        Due to the computational complexity of this operation, it must be
        called explicitly.  Please note that this math _only_ works for
        linear regressions.
        """
        self._samples.sort()

        # We need at least two points to evaluate
        if len(self._samples) < 2:
            self._slope = 0
            self._intercept = 0
            return

        # x must be monotonically increasing, so add a tweak for any equalities
        x = [float(a.x()) for a in self._samples]
        for i in range(1,len(x)):
            while x[i] <= x[i-1]:
                x[i] = x[i] + 10**-12
        x_array = np.array(x)

        y = [float(a.y()) for a in self._samples]
        y_array = np.array(y)

        weeks = [float(a.t()) for a in self._samples]
        weights = np.array([float(constants.HISTORY_HEURISTIC)**(self._max_week - i) for i in weeks])
        tck = interpolate.splrep(x_array, y_array, w=weights, k=1, quiet=1)

        x_in = [0.25, 0.75]
        y_out = interpolate.splev(x_in, tck, der=0)
        slope = (y_out[1] - y_out[0]) / (x_in[1] - x_in[0])
        intercept = y_out[1] - slope * x_in[1]

        self._slope = slope
        self._intercept = intercept
        self._tck = tck

if __name__ == "__main__":
    r = Regression()
    r.Append((1, 0.2, 3))
    r.Append((2, 0.25, 4))
    r.Append((3, 0.4, 5))
    r.Append((4, 0.5, 5))
    r.Update()

